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

# Create certificates
for service in master.ldap.test dc.samba.test; do
    openssl req -new -config "$REQ_CONFIG" -subj "$SUBJECT/CN=$service" -keyout "$OUT/$service.key" -out "$OUT/$service.csr"
    openssl x509 -req -days 7200 -extfile "$X509_CONFIG" -CA "$OUT/ca.crt" -CAkey "$OUT/ca.key" -CAcreateserial -in "$OUT/$service.csr" -out "$OUT/$service.crt"
    rm -f "$OUT/$service.csr"
done

rm -f "$OUT/ca.srl"
