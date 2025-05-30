#!/bin/bash
#
# Create sssd-ci networks.
#
# Networks created using docker-compose sets 'isolation = true', making hosts
# in other networks unroutable. A workaround is to create the networks using
# the docker command and define the network as external in docker-compose.
#
# Usage:
#   create-networks.sh
#

set -xe
source ./tools/get-container-engine.sh

${DOCKER} network inspect sssd-ci || \
    ${DOCKER} network create \
    --driver bridge \
    --subnet 172.16.100.0/24 \
    --gateway 172.16.100.1 \
    sssd-ci
${DOCKER} network inspect ipa-ci || \
    ${DOCKER} network create \
    --driver bridge \
    --subnet 172.16.110.0/24 \
    --gateway 172.16.110.1 \
    ipa-ci
