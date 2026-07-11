#!/usr/bin/env bash

set -euo pipefail

# Generate a fixed set of test certs under ./ssl:
# - CA:      ca-key.pem + ca.pem (2026-01-01 ~ 2026-07-01)
# - ETCD:    etcd-key.pem + etcd.pem (signed by CA, 2026-01-01 ~ 2027-01-01)
# - Renewed: new-ca.pem (same CA key, 2026-01-01 ~ 2027-01-01)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="${SCRIPT_DIR}"

CA_KEY="${SSL_DIR}/ca-key.pem"
CA_CERT="${SSL_DIR}/ca.pem"
ETCD_KEY="${SSL_DIR}/etcd-key.pem"
ETCD_CERT="${SSL_DIR}/etcd.pem"
NEW_CA_CERT="${SSL_DIR}/new-ca.pem"

CA_EXT="${SSL_DIR}/.ca-ext.cnf"
ETCD_EXT="${SSL_DIR}/.etcd-ext.cnf"
CA_CSR="${SSL_DIR}/.ca.csr"
ETCD_CSR="${SSL_DIR}/.etcd.csr"
NEW_CA_CSR="${SSL_DIR}/.new-ca.csr"
CA_SRL="${SSL_DIR}/.ca.srl"

# Remove temporary config/CSR/serial files at exit.
cleanup() {
  rm -f "${CA_EXT}" "${ETCD_EXT}" "${CA_CSR}" "${ETCD_CSR}" "${NEW_CA_CSR}" "${CA_SRL}"
}
trap cleanup EXIT

# Minimal x509v3 extensions for a usable CA cert.
cat > "${CA_EXT}" <<'EOF'
[v3_ca]
basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign,cRLSign
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
EOF

# Extensions for etcd leaf cert (not a CA).
cat > "${ETCD_EXT}" <<'EOF'
[v3_etcd]
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
EOF

# 1) Generate root CA key and CSR, then self-sign CA cert.
openssl genrsa -out "${CA_KEY}" 2048
openssl req -new \
  -key "${CA_KEY}" \
  -out "${CA_CSR}" \
  -subj "/C=CN/ST=shenzhen/L=shenzhen/O=etcd/OU=System/CN=etcd-ca"

openssl x509 -req \
  -in "${CA_CSR}" \
  -signkey "${CA_KEY}" \
  -out "${CA_CERT}" \
  -not_before 20260101000000Z \
  -not_after 20260701000000Z \
  -extfile "${CA_EXT}" \
  -extensions v3_ca

# 2) Generate etcd key and CSR, then sign etcd cert with CA.
openssl genrsa -out "${ETCD_KEY}" 2048
openssl req -new \
  -key "${ETCD_KEY}" \
  -out "${ETCD_CSR}" \
  -subj "/C=CN/ST=shenzhen/L=shenzhen/O=etcd/OU=System/CN=etcd"

openssl x509 -req \
  -in "${ETCD_CSR}" \
  -CA "${CA_CERT}" \
  -CAkey "${CA_KEY}" \
  -CAserial "${CA_SRL}" \
  -CAcreateserial \
  -out "${ETCD_CERT}" \
  -not_before 20260101000000Z \
  -not_after 20270101000000Z \
  -extfile "${ETCD_EXT}" \
  -extensions v3_etcd

# 3) "Renew" CA cert by re-signing CA CSR material with same CA key.
openssl x509 -x509toreq \
  -in "${CA_CERT}" \
  -signkey "${CA_KEY}" \
  -out "${NEW_CA_CSR}"

openssl x509 -req \
  -in "${NEW_CA_CSR}" \
  -signkey "${CA_KEY}" \
  -out "${NEW_CA_CERT}" \
  -not_before 20260101000000Z \
  -not_after 20270101000000Z \
  -extfile "${CA_EXT}" \
  -extensions v3_ca

# Note:
# Verifying etcd.pem against ca.pem may show "expired" at current date
# because ca.pem intentionally ends at 2026-07-01 for testing.
echo "Generated files:"
echo "  ${CA_KEY}"
echo "  ${CA_CERT}"
echo "  ${ETCD_KEY}"
echo "  ${ETCD_CERT}"
echo "  ${NEW_CA_CERT}"
