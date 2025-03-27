#!/bin/bash
#
# Generate service and user SSH keys.
#
# Usage:
#   gen-certs.sh [output=data/ssh-keys]
#

# Output directory
OUT="${1:-$(realpath `dirname "$0"`/../../data/ssh-keys)}"

echo "Creating service and user SSH keys"
echo "Output directory: $OUT"

set -xe
mkdir -p $OUT

ssh-keygen -C "Well known key for sssd-ci ci user." -t rsa -b 4096 -f "$OUT/ci.id_rsa" -N "" <<< y
ssh-keygen -C "Well known key for sssd-ci root user." -t rsa -b 4096 -f "$OUT/root.id_rsa" -N "" <<< y
