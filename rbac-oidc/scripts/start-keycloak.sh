#!/bin/bash

set -e

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

check_requirements

# Check if Keycloak is healthy
check_keycloak_health() {
    local timeout=120
    log_inf "Waiting for Keycloak to be ready..."

    while [ $timeout -gt 0 ]; do
        if curl -ks "${KEYCLOAK_HTTPS_URL}/realms/master" >/dev/null 2>&1; then
            log_suc "Keycloak is ready!"
            return 0
        fi
        sleep 2
        timeout=$((timeout - 2))
    done

    log_err "Keycloak failed to start within 2 minutes"
    return 1
}

# Check and update /etc/hosts for container name resolution
check_and_update_hosts() {
    local host_entry=$( printf "127.0.0.1\t${KEYCLOAK_CONTAINER_NAME}" )

    log_inf "Checking /etc/hosts for container name resolution..."

    if grep -q "127.0.0.1.*${KEYCLOAK_CONTAINER_NAME}" /etc/hosts; then
        log_inf "Host entry for '${KEYCLOAK_CONTAINER_NAME}' already exists in /etc/hosts"
    else
        log_inf "Adding host entry for '${KEYCLOAK_CONTAINER_NAME}' to /etc/hosts..."
        echo "${host_entry}" | sudo tee -a /etc/hosts >/dev/null
        if [ $? -eq 0 ]; then
            log_suc "Successfully added '${host_entry}' to /etc/hosts"
        else
            log_err "Failed to add host entry to /etc/hosts"
            log_err "Please manually add: ${host_entry}"
            return 1
        fi
    fi
}

log_inf "Starting Keycloak ${KEYCLOAK_VERSION}..."

# Create network if it doesn't exist
create_network_if_not_exists ${NETWORK_NAME}

# Remove existing container if it exists
remove_container_if_exists ${KEYCLOAK_CONTAINER_NAME}

# Start Keycloak container
log_inf "Starting Keycloak container on network '${NETWORK_NAME}'..."
set -x
${CONTAINER_CMD} run -d \
    --name ${KEYCLOAK_CONTAINER_NAME} \
    --network ${NETWORK_NAME} \
    -p ${KEYCLOAK_HTTP_PORT}:8080 \
    -p ${KEYCLOAK_HTTPS_PORT}:8443 \
    -e KC_BOOTSTRAP_ADMIN_USERNAME=${KEYCLOAK_ADMIN_USER} \
    -e KC_BOOTSTRAP_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD} \
    -e KC_HOSTNAME_STRICT=false \
    -e KC_HOSTNAME_STRICT_HTTPS=false \
    -e KC_HTTPS_KEY_STORE_FILE=/certs/keycloak.p12 \
    -e KC_HTTPS_KEY_STORE_PASSWORD=${KEYCLOAK_KS_PASSWORD} \
    -v ${KEYCLOAK_CONFIG_DIR}/certs:/certs:ro \
    ${KEYCLOAK_IMAGE} \
    start-dev --verbose
set +x

# Wait for Keycloak to be ready
if ! check_keycloak_health; then
    exit 1
fi

# Import realm configuration
log_inf "Importing Keycloak realm configuration..."

# Get admin access token
log_inf "Getting admin access token..."
ADMIN_TOKEN=$(curl -ks -X POST \
    "${KEYCLOAK_HTTPS_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | \
    jq -r '.access_token')

if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
    log_err "Failed to get admin access token"
    exit 1
fi

# Import the realm
log_inf "Importing realm configuration..."
curl -ks -X POST \
    "${KEYCLOAK_HTTPS_URL}/admin/realms" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "@${KEYCLOAK_CONFIG_DIR}/realm-config.json" > /dev/null

# Verify realm was created
REALM_CHECK=$(curl -ks \
    "${KEYCLOAK_HTTPS_URL}/admin/realms/${KEYCLOAK_REALM}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | \
    jq -r '.realm // "null"')

if [ "$REALM_CHECK" = "${KEYCLOAK_REALM}" ]; then
    log_suc "Realm '${KEYCLOAK_REALM}' imported successfully"
else
    log_wrn "Realm may already exist or import failed, continuing..."
fi

# Check and update /etc/hosts for container name resolution
check_and_update_hosts

echo ""
log_suc "Keycloak ${KEYCLOAK_VERSION} is running!"
log_inf "=================================="
log_inf "Container: ${KEYCLOAK_CONTAINER_NAME}"
log_inf "Network: ${NETWORK_NAME}"
log_inf "Admin Console HTTP: ${KEYCLOAK_HTTP_URL}/admin"
log_inf "Admin Console HTTPS: ${KEYCLOAK_HTTPS_URL}/admin"
log_inf "Admin user: ${KEYCLOAK_ADMIN_USER}"
log_inf "Admin password: ${KEYCLOAK_ADMIN_PASSWORD}"
log_inf "Realm: ${KEYCLOAK_REALM}"
log_inf "Client ID: ${KEYCLOAK_CLIENT_ID}"
log_inf "Issuer URL: ${KEYCLOAK_ISSUER_URL}"
echo ""
log_inf "Test users:"
log_inf "  alice:password123 (cluster-admins group)"
log_inf "  bob:password123 (developers group)"
log_inf "  charlie:password123 (viewers group)"
echo ""
log_inf "Network information:"
log_inf "  Network name: ${NETWORK_NAME}"
log_inf "  Connect other containers: ${CONTAINER_CMD} run --network ${NETWORK_NAME} ..."
log_inf "  Container hostname: ${KEYCLOAK_CONTAINER_NAME}"
echo ""
log_inf "To stop Keycloak:"
log_inf "  ${CONTAINER_CMD} stop ${KEYCLOAK_CONTAINER_NAME}"
echo ""
