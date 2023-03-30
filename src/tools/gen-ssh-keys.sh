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
mkdir -p $OUT/hosts

for name in client ldap ipa samba nfs kdc master.keycloak.test; do
    for type in ecdsa ed25519 rsa; do
        ssh-keygen -C "Well known key for sssd-ci." -t ecdsa -f "$OUT/hosts/$name.${type}_key" -N "" <<< y
    done
done

ssh-keygen -C "Well known key for sssd-ci ci user." -t rsa -b 4096 -f "$OUT/ci.id_rsa" -N "" <<< y
ssh-keygen -C "Well known key for sssd-ci root user." -t rsa -b 4096 -f "$OUT/root.id_rsa" -N "" <<< y
