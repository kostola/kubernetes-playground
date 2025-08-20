#!/bin/bash

# Global configuration

export NAME_PREFIX="${NAME_PREFIX:-k8spg-rbac-oidc}"

# Keycloak configuration
export KEYCLOAK_CONTAINER_NAME="${NAME_PREFIX}-keycloak"
export KEYCLOAK_VERSION="26.3.2"
export KEYCLOAK_IMAGE="quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}"
export KEYCLOAK_HTTP_PORT="8080"
export KEYCLOAK_HTTPS_PORT="8443"
export KEYCLOAK_ADMIN_USER="admin"
export KEYCLOAK_ADMIN_PASSWORD="admin123"
export KEYCLOAK_REALM="kubernetes"
export KEYCLOAK_CLIENT_ID="kubernetes"
export KEYCLOAK_CLIENT_SECRET="kubernetes-secret"

# Network configuration
export NETWORK_NAME="${NAME_PREFIX}"

# Kubernetes cluster configuration
export CLUSTER_NAME="${NAME_PREFIX}-cluster"
export KUBECTL_CONTEXT="kind-${CLUSTER_NAME}"

# Paths
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
export KEYCLOAK_CONFIG_DIR="${PROJECT_ROOT}/keycloak"
export KEYCLOAK_CERTS_DIR="${KEYCLOAK_CONFIG_DIR}/certs"
export K8S_CONFIG_DIR="${PROJECT_ROOT}/k8s"
export RBAC_CONFIG_FILE="${K8S_CONFIG_DIR}/rbac.yaml"
export KUBECONFIG_EXPORT_FILE="${K8S_CONFIG_DIR}/kubeconfig.yaml"
export KEYCLOAK_HTTPS_URL="https://localhost:${KEYCLOAK_HTTPS_PORT}"
export KEYCLOAK_HTTP_URL="http://localhost:${KEYCLOAK_HTTP_PORT}"
export KEYCLOAK_ISSUER_URL="https://${KEYCLOAK_CONTAINER_NAME}:8443/realms/${KEYCLOAK_REALM}"

# Keycloak certificate configuration
export CA_CERT_FILE="${KEYCLOAK_CERTS_DIR}/ca.crt"
export CA_KEY_FILE="${KEYCLOAK_CERTS_DIR}/ca.key"
export KEYCLOAK_CERT_FILE="${KEYCLOAK_CERTS_DIR}/keycloak.crt"
export KEYCLOAK_CSR_FILE="${KEYCLOAK_CERTS_DIR}/keycloak.csr"
export KEYCLOAK_KEY_FILE="${KEYCLOAK_CERTS_DIR}/keycloak.key"
export KEYCLOAK_KS_FILE="${KEYCLOAK_CERTS_DIR}/keycloak.p12"
export KEYCLOAK_KS_PASSWORD="password"

# Log functions
log_inf() {
    printf "\e[1;37m[INF] $1\e[0m\n"
}

log_err() {
    printf "\033[1;31m[ERR] $1\e[0m\n" >&2
}

log_suc() {
    printf "\e[1;32m[SUC] $1\e[0m\n"
}

log_wrn() {
    printf "\e[1;33m[WRN] $1\e[0m\n" >&2
}

# Container runtime detection and configuration
detect_container_runtime() {
    if command -v podman &> /dev/null; then
        export CONTAINER_RUNTIME="podman"
        export CONTAINER_CMD="podman"
        log_inf "Using Podman as container runtime"
    elif command -v docker &> /dev/null; then
        export CONTAINER_RUNTIME="docker"
        export CONTAINER_CMD="docker"
        log_inf "Using Docker as container runtime"
    else
        log_err "Error: Neither Podman nor Docker is installed"
        log_err "Please install one of them:"
        log_err "  # Podman (preferred):"
        log_err "  brew install podman"
        log_err "  # Docker:"
        log_err "  brew install docker"
        exit 1
    fi
}

# Check if container exists
container_exists() {
    local container_name="$1"
    ${CONTAINER_CMD} ps -a --format '{{.Names}}' | grep -q "^${container_name}$"
}

# Remove container if it exists
remove_container_if_exists() {
    local container_name="$1"
    if container_exists "${container_name}"; then
        log_inf "Removing existing container: ${container_name}"
        ${CONTAINER_CMD} stop "${container_name}" >/dev/null 2>&1 || true
        ${CONTAINER_CMD} rm "${container_name}" >/dev/null 2>&1 || true
    fi
}

# Check if network exists
network_exists() {
    local network_name="$1"
    ${CONTAINER_CMD} network ls --format '{{.Name}}' | grep -q "^${network_name}$"
}

# Create network if it doesn't exist
create_network_if_not_exists() {
    local network_name="$1"
    if ! network_exists "${network_name}"; then
        log_inf "Creating network: ${network_name}"
        ${CONTAINER_CMD} network create "${network_name}" >/dev/null
        log_suc "Network '${network_name}' created successfully"
    else
        log_inf "Network '${network_name}' already exists"
    fi
}

# Initialize container runtime detection
detect_container_runtime

# Check if container is running
is_container_running() {
    local container_name="$1"
    ${CONTAINER_CMD} ps --format '{{.Names}}' | grep -q "^${container_name}$"
}

# Check Kubernetes requirements
check_k8s_requirements() {
    check_requirements
}

# Check requirements
check_requirements() {
    if ! command -v curl &> /dev/null; then
        log_err "curl is required but not installed"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_err "jq is required but not installed"
        log_err "Install jq with: brew install jq"
        exit 1
    fi

    if [ -z "${CONTAINER_CMD}" ]; then
        log_err "Container runtime not properly detected"
        exit 1
    fi

    if ! command -v kubectl &> /dev/null; then
        log_err "kubectl is required but not installed"
        log_err "Install kubectl with: brew install kubectl"
        exit 1
    fi

    if ! command -v kind &> /dev/null; then
        log_err "kind is required but not installed"
        log_err "Install kind with: brew install kind"
        exit 1
    fi

    if ! command -v envsubst &> /dev/null; then
        log_err "envsubst is required but not installed"
        log_err "envsubst is part of gettext package"
        log_err "Install with: brew install gettext"
        exit 1
    fi
}

check_requirements
