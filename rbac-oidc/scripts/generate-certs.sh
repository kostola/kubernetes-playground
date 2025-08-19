#!/bin/bash

set -e

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

log_inf "Generating self-signed certificate for Keycloak HTTPS..."

# Create certs directory if it doesn't exist
mkdir -p "${KEYCLOAK_CERTS_DIR}"

# Generate CA private key
if [ ! -f "${CA_KEY_FILE}" ]; then
    log_inf "Generating CA key..."
    openssl genrsa -out "${CA_KEY_FILE}" 4096
else
    log_inf "CA key already present"
fi

# Generate CA certificate
if [ ! -f "${CA_CERT_FILE}" ]; then
    log_inf "Generating CA certificate..."
    openssl req -x509 -new -nodes -key "${CA_KEY_FILE}" -sha256 -days 3650 -out "${CA_CERT_FILE}" \
        -subj "/C=IT/ST=MI/L=Milan/O=CA/OU=IT/CN=localhost"
else
    log_inf "CA certificate already present"
fi

# Generate Keycloak private key
if [ ! -f "${KEYCLOAK_KEY_FILE}" ]; then
    log_inf "Generating Keycloak key..."
    openssl genrsa -out "${KEYCLOAK_KEY_FILE}" 2048
else
    log_inf "Keycloak key already present"
fi

# Generate Keycloak certificate signing request
if [ ! -f "${KEYCLOAK_CSR_FILE}" ]; then
    log_inf "Generating Keycloak CSR..."
    openssl req -new -key "${KEYCLOAK_KEY_FILE}" -out "${KEYCLOAK_CSR_FILE}" \
        -subj "/C=IT/ST=MI/L=Milan/O=Test/OU=IT/CN=localhost"
else
    log_inf "Keycloak CSR already present"
fi

# Generate Keycloak certificate
if [ ! -f "${KEYCLOAK_CERT_FILE}" ]; then
    log_inf "Generating Keycloak certificate..."
    openssl x509 -req -days 365 -in "${KEYCLOAK_CSR_FILE}" -CA "${CA_CERT_FILE}" -CAkey "${CA_KEY_FILE}" -out "${KEYCLOAK_CERT_FILE}" \
    -extensions v3_req -extfile <(cat <<EOF
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = keycloak.local
DNS.3 = ${KEYCLOAK_CONTAINER_NAME}
IP.1 = 127.0.0.1
EOF
)
else
    log_inf "Keycloak certificate already present"
fi

# Convert to PKCS12 format for Keycloak
if [ ! -f "${KEYCLOAK_KS_FILE}" ]; then
    log_inf "Converting Keycloak certificate to PKCS12 keystore..."
    openssl pkcs12 -export -in "${KEYCLOAK_CERT_FILE}" -inkey "${KEYCLOAK_KEY_FILE}" -out "${KEYCLOAK_KS_FILE}" \
        -name keycloak -passout pass:${KEYCLOAK_KS_PASSWORD}
else
    log_inf "Keycloak PKCS12 keystore already present"
fi

# Clean up CSR file
rm -f "${KEYCLOAK_CSR_FILE}"

# Set appropriate permissions
chmod 600 "${CA_KEY_FILE}" "${KEYCLOAK_KEY_FILE}" "${KEYCLOAK_KS_FILE}"
chmod 644 "${CA_CERT_FILE}" "${KEYCLOAK_CERT_FILE}"

echo ""
log_suc "Certificate generated successfully!"
log_suc "CA certificate file: ${CA_CERT_FILE}"
log_suc "CA private key file: ${CA_KEY_FILE}"
log_suc "Certificate file: ${KEYCLOAK_CERT_FILE}"
log_suc "Private key file: ${KEYCLOAK_KEY_FILE}"
log_suc "Keystore file: ${KEYCLOAK_KS_FILE}"
log_suc "Keystore password: ${KEYCLOAK_KS_PASSWORD}"
echo ""

set +e

log_inf "CA certificate details:"
openssl x509 -in "${CA_CERT_FILE}" -text -noout | grep "Subject:"
echo ""
log_inf "Certificate details:"
openssl x509 -in "${KEYCLOAK_CERT_FILE}" -text -noout | grep "Issuer:"
openssl x509 -in "${KEYCLOAK_CERT_FILE}" -text -noout | grep -A 1 "Subject:"
openssl x509 -in "${KEYCLOAK_CERT_FILE}" -text -noout | grep -A 5 "Subject Alternative Name"
echo ""
