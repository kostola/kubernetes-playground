#!/bin/bash

set -e

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

export ENDPOINT="${KEYCLOAK_ISSUER_URL}/protocol/openid-connect/token"

kubectl_config() {
    local ID_TOKEN=$(curl -k -X POST $ENDPOINT \
        -d grant_type=password \
        -d client_id=${KEYCLOAK_CLIENT_ID} \
        -d client_secret=${KEYCLOAK_CLIENT_SECRET} \
        -d username=$1 \
        -d password=password123 \
        -d scope=openid \
        -d response_type=id_token | jq -r '.id_token')

    local REFRESH_TOKEN=$(curl -k -X POST $ENDPOINT \
        -d grant_type=password \
        -d client_id=${KEYCLOAK_CLIENT_ID} \
        -d client_secret=${KEYCLOAK_CLIENT_SECRET} \
        -d username=$1 \
        -d password=password123 \
        -d scope=openid \
        -d response_type=id_token | jq -r '.refresh_token')

    local CA_DATA=$(cat "${CA_CERT_FILE}" | base64 | tr -d '\n')

    kubectl config set-credentials $1 \
        --auth-provider=oidc \
        --auth-provider-arg=client-id=${KEYCLOAK_CLIENT_ID} \
        --auth-provider-arg=client-secret=${KEYCLOAK_CLIENT_SECRET} \
        --auth-provider-arg=idp-issuer-url=${KEYCLOAK_ISSUER_URL} \
        --auth-provider-arg=id-token=$ID_TOKEN \
        --auth-provider-arg=refresh-token=$REFRESH_TOKEN \
        --auth-provider-arg=idp-certificate-authority-data=$CA_DATA

    kubectl config set-context "user-$1" --cluster="${KUBECTL_CONTEXT}" --user=$1
}

set -x

# setup config for our users
kubectl_config alice
kubectl_config bob
kubectl_config charlie
