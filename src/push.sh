#!/bin/bash

#                     ==============
#                      IMAGE LAYERS
#                     ==============
#
#                     original image
# |----------------------------------------------------|
# |                    base-ground                    |
# |----------------------------------------------------|
# |        base-ldap    |  base-client  |  base-samba  |
# |------------------------------------ |--------------|
# |  base-ipa  |        |               |              |
# |------------|        |               |              |
# |    ipa     |  ldap  |    client     |     samba    |
# |            |        |---------------|              |
# |            |        |  client-dev   |              |
# |------------|--------|---------------|--------------|

trap "cleanup &> /dev/null || :" EXIT
pushd $(realpath `dirname "$0"`) &> /dev/null
source ./tools/get-container-engine.sh

# Additional tags of the image
EXTRA_TAGS="${EXTRA_TAGS:-}"

# REGISTRY is required
if [ -z "$REGISTRY" ]; then
  echo "REGISTRY environment variable have to be set."
  exit 1
fi

# TAG is required
if [ -z "$TAG" ]; then
  echo "TAG environment variable have to be set."
  exit 1
fi

echo "Pushing to $REGISTRY with tag $TAG."

set -xe

function push {
  local name=$1
  local tag=$2
  local extra_tags=$3

  ${DOCKER} push "localhost/sssd/$name:$tag" "${REGISTRY}/$name:$tag"

  for extra in $extra_tags; do
    ${DOCKER} push "localhost/sssd/$name:$tag" "${REGISTRY}/$name:$extra"
  done
}

# Push base images
push ci-base-client "$TAG" "$EXTRA_TAGS"
push ci-base-ipa "$TAG" "$EXTRA_TAGS"
push ci-base-ldap "$TAG" "$EXTRA_TAGS"
push ci-base-samba "$TAG" "$EXTRA_TAGS"
push ci-base-nfs "$TAG" "$EXTRA_TAGS"

# Push service images
push ci-dns latest ""
push ci-client "$TAG" "$EXTRA_TAGS"
push ci-client-devel "$TAG" "$EXTRA_TAGS"
push ci-ipa "$TAG" "$EXTRA_TAGS"
push ci-ldap "$TAG" "$EXTRA_TAGS"
push ci-samba "$TAG" "$EXTRA_TAGS"
push ci-nfs "$TAG" "$EXTRA_TAGS"
