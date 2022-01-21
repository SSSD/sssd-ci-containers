#!/bin/bash
#
# Trust sssd-ci CA.
#
# Usage:
#   trust-ca.sh
#

CA="${1:-$(realpath `dirname "$0"`/../../data/certs/ca.crt)}"

set -xe
cp "$CA" /etc/pki/ca-trust/source/anchors/sssd-ci-ca.crt
update-ca-trust
