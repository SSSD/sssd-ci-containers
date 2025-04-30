#!/bin/bash

#                     ==============
#                      IMAGE LAYERS
#                     ==============
#
#                     original image
# |------------------------------------------------------------------------------------------------|
# |                                       base-ground                                              |
# |------------------------------------------------------------------------------------------------|
# |        base-ldap    |  base-client  |  base-samba  |  base-nfs  |  base-keycloak  |  base-kdc  |
# |------------------------------------ |--------------|------------|-----------------|------------|
# |  base-ipa  |        |               |              |            |                 |            |
# |------------|        |               |              |            |                 |            |
# |    ipa     |  ldap  |    client     |     samba    |    nfs     |    keycloak     |     kdc    |
# |            |        |---------------|              |            |                 |            |
# |            |        |  client-dev   |              |            |                 |            |
# |------------|--------|---------------|--------------|------------|-----------------|------------|

trap "cleanup &> /dev/null || :" EXIT
pushd $(realpath `dirname "$0"`) &> /dev/null
source ./tools/get-container-engine.sh

export REGISTRY="localhost/sssd"
export BASE_IMAGE="${BASE_IMAGE:-registry.fedoraproject.org/fedora:latest}"
export TAG="${TAG:-latest}"
export UNAVAILABLE="${UNAVAILABLE:-}"
export ANSIBLE_CONFIG=./ansible/ansible.cfg
export ANSIBLE_OPTS=${ANSIBLE_OPTS:-}
export ANSIBLE_DEBUG=${ANSIBLE_DEBUG:-0}

# Debugging options
export CLEANUP=${CLEANUP:-yes}
export SKIP_BASE=${SKIP_BASE:-no}

echo "Building from: $BASE_IMAGE"
echo "Building with tag: $TAG"
echo "Building in priviledged mode: $PRIVILEDGED"
echo "Storing in: $REGISTRY"

if [ "$CLEANUP" == "no" ]; then
  trap - EXIT
fi

set -xe

function cleanup {
  ${DOCKER} rm sssd-wip-base --force || :
  compose down
}

function compose {
  docker-compose -f "../docker-compose.yml" -f "./docker-compose.build.yml" $@
}

function base_exec {
  ${DOCKER} exec sssd-wip-base /bin/bash -c "$1"
}

function c8s_repo {
    # Update repos to working ones
    ${DOCKER} exec sssd-wip-base /bin/bash -c 'grep -q "CentOS Stream 8" /etc/os-release && sed -i "s/mirrorlist/#mirrorlist/g" /etc/yum.repos.d/CentOS-* || true'
    ${DOCKER} exec sssd-wip-base /bin/bash -c 'grep -q "CentOS Stream 8" /etc/os-release && sed -i "s|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g" /etc/yum.repos.d/CentOS-* || true'
}

# Make sure that Ansible dependencies are installed so we can run playbooks
function base_install_python {
  # Install python3 if not available
  if base_exec '[ ! -f /usr/bin/python3 ]'; then
    if base_exec '[ -f /usr/bin/apt ]'; then
      base_exec 'apt update && apt install -y python3 python3-apt && rm -rf /var/lib/apt/lists/*'
    else
      base_exec 'dnf install -y python3 && dnf clean all'
    fi
  fi

  # Add python3-dnf5 to enable ansible to use it
  if base_exec '[ -f /usr/bin/dnf5 ]'; then
    base_exec 'dnf install -y python3-libdnf5 dnf5-plugins'
  fi
}

# We use commit instead of build so we can provision the images with Ansible.
function build_base_image {
  local from=$1
  local name=$2

  for svc in $UNAVAILABLE; do
    if [ "base-$svc" != $name ]; then
      continue
    fi

    echo "Service $svc is not available in $BASE_IMAGE."
    echo "Using quay.io/sssd/ci-base-$svc:latest instead."
    ${DOCKER} pull "quay.io/sssd/ci-base-$svc:latest"
    ${DOCKER} tag "quay.io/sssd/ci-base-$svc:latest" "${REGISTRY}/ci-$name:${TAG}"
    return 0
  done

  echo "Building $name from $from"
  ${DOCKER} run --security-opt seccomp=unconfined --name sssd-wip-base --detach -i "$from"
  if [ $name == 'base-ground' ]; then
    c8s_repo
    base_install_python
  fi
  ansible-playbook $ANSIBLE_OPTS --limit "`echo $name | sed -r 's/-/_/g'`" ./ansible/playbook_image_base.yml
  ${DOCKER} stop sssd-wip-base
  ${DOCKER} commit                     \
    --change 'CMD ["/sbin/init"]'      \
    --change 'STOPSIGNAL SIGRTMIN+3'   \
    sssd-wip-base "${REGISTRY}/ci-$name:${TAG}"
  ${DOCKER} rm sssd-wip-base --force
}

# We have to use commit because the services require functional systemd.
function build_service_image {
  local from=$1
  local name=$2

  echo "Commiting $from as $name"
  ${DOCKER} commit "$from" "${REGISTRY}/ci-$name:${TAG}"
}

if [ "$SKIP_BASE" == 'no' ]; then
  # Create base images
  ${DOCKER} build --file "Containerfile" --target dns --tag "${REGISTRY}/ci-dns:latest" .
  build_base_image "$BASE_IMAGE" base-ground
  build_base_image "ci-base-ground:${TAG}" base-client
  build_base_image "ci-base-ground:${TAG}" base-ldap
  build_base_image "ci-base-ground:${TAG}" base-samba
  build_base_image "ci-base-ldap:${TAG}"   base-ipa
  build_base_image "ci-base-ground:${TAG}" base-nfs
  build_base_image "ci-base-ground:${TAG}" base-kdc
  build_base_image "ci-base-ground:${TAG}" base-keycloak
fi

# Create services
compose up --detach
ansible-playbook $ANSIBLE_OPTS ./ansible/playbook_image_service.yml
compose stop
build_service_image sssd-wip-client client
build_service_image sssd-wip-ipa ipa
build_service_image sssd-wip-ipa2 ipa2
build_service_image sssd-wip-ldap ldap
build_service_image sssd-wip-samba samba
build_service_image sssd-wip-nfs nfs
build_service_image sssd-wip-kdc kdc
build_service_image sssd-wip-keycloak keycloak
compose down

# Create development images with additional packages
build_base_image "ci-client:${TAG}" client-devel
build_base_image "ci-ipa:${TAG}" ipa-devel
