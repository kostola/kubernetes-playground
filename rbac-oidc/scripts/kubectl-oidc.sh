#!/bin/bash

set -e

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Check for required parameters
if [ $# -lt 2 ]; then
    echo "Usage: $0 <username> <password>"
    echo ""
    echo "Configure kubectl OIDC authentication for a user"
    echo ""
    echo "Examples:"
    echo "  $0 alice password123"
    echo "  $0 bob mypassword"
    exit 1
fi

USERNAME="$1"
PASSWORD="$2"

export ENDPOINT="${KEYCLOAK_ISSUER_URL}/protocol/openid-connect/token"

kubectl_config() {
    local username="$1"
    local password="$2"

    log_inf "Configuring kubectl OIDC for user: ${username}"

    local ID_TOKEN=$(curl -k -X POST $ENDPOINT \
        -d grant_type=password \
        -d client_id=${KEYCLOAK_CLIENT_ID} \
        -d client_secret=${KEYCLOAK_CLIENT_SECRET} \
        -d username="${username}" \
        -d password="${password}" \
        -d scope=openid \
        -d response_type=id_token | jq -r '.id_token')

    local REFRESH_TOKEN=$(curl -k -X POST $ENDPOINT \
        -d grant_type=password \
        -d client_id=${KEYCLOAK_CLIENT_ID} \
        -d client_secret=${KEYCLOAK_CLIENT_SECRET} \
        -d username="${username}" \
        -d password="${password}" \
        -d scope=openid \
        -d response_type=id_token | jq -r '.refresh_token')

    local CA_DATA=$(cat "${CA_CERT_FILE}" | base64 | tr -d '\n')

    kubectl config set-credentials "${username}" \
        --auth-provider=oidc \
        --auth-provider-arg=client-id=${KEYCLOAK_CLIENT_ID} \
        --auth-provider-arg=client-secret=${KEYCLOAK_CLIENT_SECRET} \
        --auth-provider-arg=idp-issuer-url=${KEYCLOAK_ISSUER_URL} \
        --auth-provider-arg=id-token=$ID_TOKEN \
        --auth-provider-arg=refresh-token=$REFRESH_TOKEN \
        --auth-provider-arg=idp-certificate-authority-data=$CA_DATA

    kubectl config set-context "user-${username}" --cluster="${KUBECTL_CONTEXT}" --user="${username}"

    log_suc "Successfully configured kubectl OIDC for user: ${username}"
}

# Configure OIDC for the specified user
kubectl_config "${USERNAME}" "${PASSWORD}"
