#!/bin/bash
#
# Remove sssd-ci networks.
#
# Usage:
#   remove-networks.sh
#

set -xe
source ./src/tools/get-container-engine.sh

${DOCKER} network rm ipa-ci -f
${DOCKER} network rm sssd-ci -f
