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
# |------------|        |---------------|              |            |                 |            |
# | ipa-devel  |        | client-devel  |              |            |                 |            |
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
export SHARED_CACHE_ROOT="$(mktemp -d)"

# Debugging options
export CLEANUP=${CLEANUP:-yes}
export SKIP_BASE=${SKIP_BASE:-no}

echo "Building from: $BASE_IMAGE"
echo "Building with tag: $TAG"
echo "Storing in: $REGISTRY"

if [ "$CLEANUP" == "no" ]; then
  trap - EXIT
fi
if [ "$SKIP_BASE" == "yes" ]; then
  unset BASE_IMAGE
fi

set -xe

function cleanup {
  ${DOCKER} rm sssd-wip-base --force || :
  rm --recursive --force "$SHARED_CACHE_ROOT"
  compose down
}

function compose {
  docker-compose -f "../docker-compose.yml" -f "../docker-compose.keycloak.yml" -f "./docker-compose.build.yml" $@
}

function base_run {
  local image="${BASE_IMAGE:-ci-base-ground:${TAG}}"

  ${DOCKER} run --rm "$image" /bin/bash -c "$1"
}

function base_exec {
  ${DOCKER} exec sssd-wip-base /bin/bash -c "$1"
}

# Make sure that Ansible dependencies are installed so we can run playbooks
function base_install_python {
  # Install python3 if not available
  case "${PACKAGE_MANAGER}" in
    */apt)
      base_exec 'command -v python3 || (apt update && DEBIAN_FRONTEND=noninteractive apt install -y python3 python3-apt)'
      ;;
    */dnf)
      base_exec 'command -v python3 || dnf install -y python3'
      ;;
  esac
}

# We use commit instead of build so we can provision the images with Ansible.
function build_base_image {
  local from=$1
  local name=$2
  local -a volume_opts

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

  for target in $SHARED_CACHE_TARGETS; do
    mkdir --parents "$SHARED_CACHE_ROOT/$target"
    volume_opts+=("--volume" "$SHARED_CACHE_ROOT/$target:$target:z")
  done

  echo "Building $name from $from"
  ${DOCKER} run ${volume_opts[@]} --security-opt seccomp=unconfined --name sssd-wip-base --detach -i "$from"
  if [ $name == 'base-ground' ]; then
    base_install_python
  fi

  ansible-playbook --limit "`echo $name | sed -r 's/-/_/g'`" ./ansible/playbook_image_base.yml

  if [ $name == 'base-ground' ]; then
    ${DOCKER} attach --no-stdin sssd-wip-base
  else
    ${DOCKER} stop sssd-wip-base
  fi
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

PACKAGE_MANAGER=$(base_run 'command -v apt || command -v dnf')
case "$PACKAGE_MANAGER" in
  */apt)
    SHARED_CACHE_TARGETS="/var/cache/apt /var/lib/apt/lists"
    ;;
  */dnf)
    SHARED_CACHE_TARGETS="/var/cache/dnf"
    ;;
esac

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
build_service_image sssd-wip-ldap ldap
build_service_image sssd-wip-samba samba
build_service_image sssd-wip-nfs nfs
build_service_image sssd-wip-kdc kdc
build_service_image sssd-wip-keycloak keycloak
compose down

# Create development images with additional packages
build_base_image "ci-client:${TAG}" client-devel
build_base_image "ci-ipa:${TAG}" ipa-devel

rm --recursive --force "$SHARED_CACHE_ROOT"
