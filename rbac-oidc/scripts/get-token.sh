#!/bin/bash

set -e

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Check if username is provided
if [ $# -ne 1 ]; then
    log_inf "Usage: $0 <username>"
    echo ""
    log_inf "Available test users:"
    log_inf "  alice    (cluster-admins group)"
    log_inf "  bob      (developers group)"
    log_inf "  charlie  (viewers group)"
    echo ""
    log_inf "Password for all users: password123"
    exit 1
fi

USERNAME=$1
PASSWORD="password123"

log_inf "Getting OIDC token for user: ${USERNAME}"

# Check if Keycloak is running
if ! is_container_running ${KEYCLOAK_CONTAINER_NAME}; then
    log_err "Keycloak container '${KEYCLOAK_CONTAINER_NAME}' is not running"
    log_err "Please start Keycloak first:"
    log_err "  ./scripts/start-keycloak.sh"
    exit 1
fi

# Get access token from Keycloak
log_inf "Requesting access token from Keycloak..."

TOKEN_RESPONSE=$(curl -ks -X POST \
    "${KEYCLOAK_ISSUER_URL}/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${USERNAME}" \
    -d "password=${PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=${KEYCLOAK_CLIENT_ID}" \
    -d "client_secret=${KEYCLOAK_CLIENT_SECRET}" \
    -d "scope=openid profile email")

# Check if token request was successful
ACCESS_TOKEN=$(echo "${TOKEN_RESPONSE}" | jq -r '.access_token // empty')
ID_TOKEN=$(echo "${TOKEN_RESPONSE}" | jq -r '.id_token // empty')

if [ -z "${ACCESS_TOKEN}" ] || [ "${ACCESS_TOKEN}" = "null" ]; then
    log_err "Failed to get access token"
    log_err "Response from Keycloak:"
    log_err "${TOKEN_RESPONSE}" | jq '.'
    exit 1
fi

log_suc "Successfully obtained tokens for user: ${USERNAME}"

echo ""
log_inf "=== ACCESS TOKEN ==="
echo "${ACCESS_TOKEN}"
echo ""
log_inf "=== ID TOKEN ==="
echo "${ID_TOKEN}"
echo ""

# Decode and display token claims
echo "=== TOKEN CLAIMS ==="
echo "${ID_TOKEN}" | cut -d. -f2 | base64 -d 2>/dev/null | jq '.' || {
    # Fallback for base64 padding issues
    TOKEN_PAYLOAD="${ID_TOKEN#*.}"
    TOKEN_PAYLOAD="${TOKEN_PAYLOAD%.*}"
    # Add padding if needed
    case $((${#TOKEN_PAYLOAD} % 4)) in
        2) TOKEN_PAYLOAD="${TOKEN_PAYLOAD}==" ;;
        3) TOKEN_PAYLOAD="${TOKEN_PAYLOAD}=" ;;
    esac
    echo "${TOKEN_PAYLOAD}" | base64 -d 2>/dev/null | jq '.' || echo "Could not decode token"
}

echo ""
log_inf "=== KUBECTL USAGE ==="
log_inf "To use this token with kubectl, you can:"
echo ""
log_inf "1. Set the token manually:"
echo "kubectl config set-credentials ${USERNAME} --token=\"${ID_TOKEN}\""
echo "kubectl config set-context ${USERNAME}-context --cluster=${KUBECTL_CONTEXT#kind-} --user=${USERNAME}"
echo "kubectl config use-context ${USERNAME}-context"
echo ""
log_inf "2. Or test directly:"
echo "kubectl --token=\"${ID_TOKEN}\" get pods"
echo ""
log_inf "Note: Use ID_TOKEN for kubectl (contains user/group claims)"
log_inf "      Use ACCESS_TOKEN for API calls (contains scopes)"
echo ""
