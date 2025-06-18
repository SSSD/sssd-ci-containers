#!/bin/bash
#
# Remove sssd-ci networks.
#
# Usage:
#   remove-networks.sh
#

default=docker
if which podman &> /dev/null; then
  default=podman
fi

export DOCKER="${DOCKER:-$default}"

${DOCKER} network rm ipa-ci -f
${DOCKER} network rm sssd-ci -f
