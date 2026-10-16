#!/bin/bash
#
# Generate CA and service certificates.
#
# Usage:
#   gen-certs.sh [output=data/certs]
#

# Output directory
OUT="${1:-$(realpath `dirname "$0"`/../../data/certs)}"
CONFIG_DIR="$(realpath `dirname "$0"`/../../data/configs)"
SUBJECT="/O=test/OU=sssd"
REQ_CONFIG="$CONFIG_DIR/openssl_ca.cfg"
X509_CONFIG="$CONFIG_DIR/openssl_sign_service.ext"

echo "Creating CA and service certificates"
echo "Output directory: $OUT"

set -xe
mkdir -p $OUT

# Create non-encrypted self-signed root certificate authority
openssl req -new -x509 -days 7200 -config "$REQ_CONFIG" -subj "$SUBJECT/CN=ca" -keyout "$OUT/ca.key" -out "$OUT/ca.crt"

# Extra names a service certificate must also be valid for, besides its own
# hostname. master2.ldap.test is an alias of master.ldap.test, used by failover
# topologies that need two distinct LDAP server names.
declare -A ALIASES=(
    [master.ldap.test]="master2.ldap.test"
)

# Create certificates
for service in master.ldap.test dc.samba.test master.keycloak.test; do
    # Modern TLS stacks match the hostname against subjectAltName and ignore
    # CN, so each certificate lists its own name as a SAN as well.
    san="DNS:$service"
    for alias in ${ALIASES[$service]}; do
        san="$san,DNS:$alias"
    done

    # The base extensions are shared, the SAN is per service.
    ext="$OUT/$service.ext"
    cp "$X509_CONFIG" "$ext"
    echo "subjectAltName=$san" >> "$ext"

    openssl req -new -config "$REQ_CONFIG" -subj "$SUBJECT/CN=$service" -keyout "$OUT/$service.key" -out "$OUT/$service.csr"
    openssl x509 -req -days 7200 -extfile "$ext" -CA "$OUT/ca.crt" -CAkey "$OUT/ca.key" -CAcreateserial -in "$OUT/$service.csr" -out "$OUT/$service.crt"
    rm -f "$OUT/$service.csr" "$ext"
done

rm -f "$OUT/ca.srl"
