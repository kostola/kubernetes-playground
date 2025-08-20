#!/bin/bash

set -e

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

check_k8s_requirements

log_inf "Setting up KinD cluster '${CLUSTER_NAME}' with OIDC integration..."

# Check if Keycloak is running
if ! is_container_running ${KEYCLOAK_CONTAINER_NAME}; then
    log_err "Keycloak container '${KEYCLOAK_CONTAINER_NAME}' is not running"
    log_inf "Please start Keycloak first:"
    log_inf "  ./scripts/start-keycloak.sh"
    exit 1
fi

log_inf "Keycloak container '${KEYCLOAK_CONTAINER_NAME}' is running"
log_inf "Using OIDC issuer URL: ${KEYCLOAK_ISSUER_URL}"

# Prepare CA certificate and generate kind config from template
log_inf "Preparing CA certificate and generating kind configuration..."
if [ ! -f "${CA_CERT_FILE}" ]; then
    log_err "CA certificate not found at ${CA_CERT_FILE}"
    log_inf "Please generate certificates first:"
    log_inf "  ./scripts/generate-certs.sh"
    exit 1
fi

# Ensure target directory exists
create_target_directories

# Generate kind configuration from template
KIND_CONFIG_TEMPLATE="${KEYCLOAK_CONFIG_DIR}/kind-oidc-config.tmpl.yaml"
# Note: KIND_CONFIG_FILE is defined in config.sh as ${TARGET_DIR}/kind-oidc-config.yaml

if [ ! -f "${KIND_CONFIG_TEMPLATE}" ]; then
    log_err "Kind configuration template not found at ${KIND_CONFIG_TEMPLATE}"
    exit 1
fi

log_inf "Generating kind configuration from template..."
envsubst < "${KIND_CONFIG_TEMPLATE}" > "${KIND_CONFIG_FILE}"
log_inf "Kind configuration generated at ${KIND_CONFIG_FILE}"

# Check if cluster already exists
CLUSTER_EXISTS=false
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log_wrn "KinD cluster '${CLUSTER_NAME}' already exists"
    CLUSTER_EXISTS=true

    # Verify existing cluster is accessible
    log_inf "Verifying existing cluster is accessible..."
    if kubectl cluster-info --context ${KUBECTL_CONTEXT} >/dev/null 2>&1; then
        log_inf "Existing cluster is accessible"
    else
        log_err "Existing cluster is not accessible, consider recreating it"
        log_inf "To recreate: kind delete cluster --name ${CLUSTER_NAME}"
        exit 1
    fi

    # Ensure cluster is connected to the network
    CONTROL_PLANE_CONTAINER="${CLUSTER_NAME}-control-plane"
    log_inf "Ensuring cluster is connected to network '${NETWORK_NAME}'..."
    if ${CONTAINER_CMD} network inspect "${NETWORK_NAME}" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | grep -q "${CONTROL_PLANE_CONTAINER}"; then
        log_inf "Cluster is already connected to network '${NETWORK_NAME}'"
    else
        log_inf "Connecting cluster to network '${NETWORK_NAME}'..."
        ${CONTAINER_CMD} network connect "${NETWORK_NAME}" "${CONTROL_PLANE_CONTAINER}" 2>/dev/null || log_inf "Network connection may already exist"
    fi
else
    # Create KinD cluster with OIDC configuration
    log_inf "Creating KinD cluster '${CLUSTER_NAME}' with OIDC integration..."
    kind create cluster --config "${KIND_CONFIG_FILE}"

    # Connect kind cluster to the same network as Keycloak
    log_inf "Connecting kind cluster to network '${NETWORK_NAME}'..."
    CONTROL_PLANE_CONTAINER="${CLUSTER_NAME}-control-plane"
    ${CONTAINER_CMD} network connect "${NETWORK_NAME}" "${CONTROL_PLANE_CONTAINER}"
    log_inf "Kind cluster connected to network '${NETWORK_NAME}'"

    # Wait a moment for cluster to be ready
    sleep 5

    # Verify cluster is running
    log_inf "Verifying cluster is accessible..."
    if kubectl cluster-info --context ${KUBECTL_CONTEXT} >/dev/null 2>&1; then
        log_suc "KinD cluster '${CLUSTER_NAME}' created successfully!"
    else
        log_err "Cluster created but not accessible"
        exit 1
    fi
fi

# Apply RBAC configuration for OIDC users
log_inf "Applying RBAC configuration for OIDC users..."
if [ -f "${RBAC_CONFIG_FILE}" ]; then
    if kubectl apply -f "${RBAC_CONFIG_FILE}" --context ${KUBECTL_CONTEXT} >/dev/null 2>&1; then
        log_suc "RBAC configuration applied successfully!"
    else
        log_err "Failed to apply RBAC configuration"
        exit 1
    fi
else
    log_err "RBAC configuration file not found at ${RBAC_CONFIG_FILE}"
    exit 1
fi

# Export kubeconfig for the cluster
log_inf "Exporting kubeconfig to ${KUBECONFIG_FILE}..."
if kind export kubeconfig --name "${CLUSTER_NAME}" --kubeconfig "${KUBECONFIG_FILE}"; then
    log_suc "Kubeconfig exported successfully to ${KUBECONFIG_FILE}"

    # Make kubeconfig file readable by owner only for security
    chmod 600 "${KUBECONFIG_FILE}"
    log_inf "Set kubeconfig file permissions to 600 for security"
else
    log_err "Failed to export kubeconfig"
    exit 1
fi

# Display cluster information
echo ""
if [ "$CLUSTER_EXISTS" = true ]; then
    log_suc "KinD cluster setup completed! (using existing cluster)"
else
    log_suc "KinD cluster setup completed! (cluster created)"
fi
log_inf "=================================="
log_inf "Cluster name: ${CLUSTER_NAME}"
log_inf "Kubectl context: ${KUBECTL_CONTEXT}"
log_inf "Network: ${NETWORK_NAME}"
log_inf "OIDC issuer: ${KEYCLOAK_ISSUER_URL}"
log_inf "OIDC issuer (external): ${KEYCLOAK_ISSUER_URL}"
log_inf "Keycloak Admin Console: ${KEYCLOAK_HTTPS_URL}/admin"
echo ""
log_inf "To use this cluster:"
log_inf "  kubectl --context ${KUBECTL_CONTEXT} get nodes"
log_inf "  # Or use exported kubeconfig:"
log_inf "  kubectl --kubeconfig ${KUBECONFIG_FILE} get nodes"
log_inf "  # Or set as default:"
log_inf "  export KUBECONFIG=${KUBECONFIG_FILE}"
echo ""
log_inf "To delete this cluster:"
log_inf "  kind delete cluster --name ${CLUSTER_NAME}"
echo ""
log_inf "Configuration files:"
log_inf "  Kind template: ${KIND_CONFIG_TEMPLATE}"
log_inf "  Kind config: ${KIND_CONFIG_FILE}"
log_inf "  RBAC config: ${RBAC_CONFIG_FILE}"
log_inf "  Kubeconfig export: ${KUBECONFIG_FILE}"
echo ""
log_inf "Network information:"
log_inf "  Both Keycloak and kind cluster are on network: ${NETWORK_NAME}"
log_inf "  Keycloak container hostname: ${KEYCLOAK_CONTAINER_NAME}"
log_inf "  Kind control plane: ${CONTROL_PLANE_CONTAINER}"
echo ""
log_inf "RBAC Groups configured:"
log_inf "  oidc:cluster-admins - Full cluster admin access"
log_inf "  oidc:developers - Workload management access"
log_inf "  oidc:viewers - Read-only access"
echo ""
log_inf "Test users (from Keycloak realm):"
log_inf "  alice:password123 (cluster-admins group)"
log_inf "  bob:password123 (developers group)"
log_inf "  charlie:password123 (viewers group)"
echo ""
