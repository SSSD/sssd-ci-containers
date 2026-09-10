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

default=docker
if which podman &> /dev/null; then
  default=podman
fi

export DOCKER="${DOCKER:-$default}"

echo "Creating networks..."

${DOCKER} network inspect sssd-ci &> /dev/null ||
    ${DOCKER} network create \
        --driver bridge \
        --subnet 172.16.100.0/24 \
        --gateway 172.16.100.1 \
        sssd-ci
${DOCKER} network inspect ipa-ci &> /dev/null ||
    ${DOCKER} network create  \
        --driver bridge \
        --subnet 172.16.110.0/24 \
        --gateway 172.16.110.1 \
        ipa-ci
