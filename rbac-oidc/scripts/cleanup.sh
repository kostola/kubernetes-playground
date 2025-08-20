#!/bin/bash

set -e

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Export and validate KUBECONFIG
export_and_validate_kubeconfig

# Default options
CLEANUP_CONTAINERS=false
CLEANUP_CLUSTER=false
CLEANUP_HOSTS=false
CLEANUP_FILES=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --keycloak)
            CLEANUP_CONTAINERS=true
            shift
            ;;
        --cluster)
            CLEANUP_CLUSTER=true
            shift
            ;;
        --hosts)
            CLEANUP_HOSTS=true
            shift
            ;;
        --no-files)
            CLEANUP_FILES=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Cleanup rbac-oidc testing environment"
            echo ""
            echo "OPTIONS:"
            echo "  --cluster     Remove KinD cluster"
            echo "  --hosts       Remove entries from /etc/hosts"
            echo "  --keycloak    Remove Keycloak container and network"
            echo "  --no-files    Skip cleanup of generated files"
            echo "  -h, --help    Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                # Remove K8s resources and files only"
            echo "  $0 --keycloak                     # Remove K8s resources, files, and containers"
            echo "  $0 --keycloak --cluster           # Remove everything except /etc/hosts"
            echo "  $0 --keycloak --cluster --hosts   # Complete cleanup"
            exit 0
            ;;
        *)
            log_err "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

log_inf "Starting cleanup of rbac-oidc testing environment..."

# Remove Kubernetes resources if cluster exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log_inf "Removing Kubernetes resources from cluster '${CLUSTER_NAME}'..."

    # Set kubectl context
    kubectl config use-context ${KUBECTL_CONTEXT} 2>/dev/null || true

    # Remove RBAC resources
    if [ -f "${RBAC_CONFIG_FILE}" ]; then
        kubectl delete -f "${RBAC_CONFIG_FILE}" --ignore-not-found=true --context ${KUBECTL_CONTEXT} 2>/dev/null || true
        log_suc "Removed RBAC resources"
    fi

    # Remove test resources if they exist
    if [ -f "${K8S_CONFIG_DIR}/test-resources.yaml" ]; then
        kubectl delete -f "${K8S_CONFIG_DIR}/test-resources.yaml" --ignore-not-found=true --context ${KUBECTL_CONTEXT} 2>/dev/null || true
        log_suc "Removed test resources"
    fi

    # Remove any test pods
    kubectl delete pods -l created-by=rbac-oidc-test --ignore-not-found=true --context ${KUBECTL_CONTEXT} 2>/dev/null || true
else
    log_wrn "KinD cluster '${CLUSTER_NAME}' does not exist"
fi
# Remove KinD cluster if requested
if [ "$CLEANUP_CLUSTER" = true ]; then
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        log_inf "Removing KinD cluster: ${CLUSTER_NAME}"
        kind delete cluster --name ${CLUSTER_NAME}
        log_suc "Removed KinD cluster"
    else
        log_wrn "KinD cluster '${CLUSTER_NAME}' does not exist"
    fi
fi

# Remove containers and network if requested
if [ "$CLEANUP_CONTAINERS" = true ]; then
    log_inf "Removing containers and network..."

    # Stop and remove Keycloak container
    if container_exists ${KEYCLOAK_CONTAINER_NAME}; then
        log_inf "Stopping and removing Keycloak container..."
        ${CONTAINER_CMD} stop ${KEYCLOAK_CONTAINER_NAME} >/dev/null 2>&1 || true
        ${CONTAINER_CMD} rm ${KEYCLOAK_CONTAINER_NAME} >/dev/null 2>&1 || true
        log_suc "Removed Keycloak container"
    else
        log_inf "Keycloak container '${KEYCLOAK_CONTAINER_NAME}' does not exist"
    fi

    # Remove network if it exists and is empty
    if network_exists ${NETWORK_NAME}; then
        # Check if network has other containers
        NETWORK_CONTAINERS=$(${CONTAINER_CMD} network inspect ${NETWORK_NAME} --format '{{len .Containers}}' 2>/dev/null || echo "0")
        if [ "$NETWORK_CONTAINERS" = "0" ]; then
            ${CONTAINER_CMD} network rm ${NETWORK_NAME} >/dev/null 2>&1 || true
            log_suc "Removed network: ${NETWORK_NAME}"
        else
            log_wrn "Network ${NETWORK_NAME} has other containers, not removing"
        fi
    else
        log_inf "Network '${NETWORK_NAME}' does not exist"
    fi
fi

# Remove /etc/hosts entries if requested
if [ "$CLEANUP_HOSTS" = true ]; then
    log_inf "Removing /etc/hosts entries..."

    if grep -q "127.0.0.1.*${KEYCLOAK_CONTAINER_NAME}" /etc/hosts 2>/dev/null; then
        sudo sed -i '' "/127.0.0.1.*${KEYCLOAK_CONTAINER_NAME}/d" /etc/hosts
        log_suc "Removed ${KEYCLOAK_CONTAINER_NAME} from /etc/hosts"
    else
        log_inf "No ${KEYCLOAK_CONTAINER_NAME} entries found in /etc/hosts"
    fi
fi

# Clean up generated files and certificates
if [ "$CLEANUP_FILES" = true ]; then
    log_inf "Cleaning up generated files..."

    # Remove entire target directory for this configuration
    if [ -d "${TARGET_DIR}" ]; then
        rm -rf "${TARGET_DIR}"
        log_suc "Removed target directory: ${TARGET_DIR}"
    fi

    # Remove temporary files
    rm -f /tmp/kind-oidc-config-${CLUSTER_NAME}.yaml* 2>/dev/null || true
    rm -f /tmp/keycloak-*.log 2>/dev/null || true
    log_inf "Cleaned up temporary files"

    # Clean up empty parent target directory if no other configurations exist
    if [ -d "${PROJECT_ROOT}/target" ] && [ -z "$(ls -A "${PROJECT_ROOT}/target" 2>/dev/null)" ]; then
        rm -rf "${PROJECT_ROOT}/target"
        log_inf "Removed empty target directory"
    fi
fi

echo ""
log_suc "Cleanup completed!"

# Show current state
echo ""
log_inf "Current state:"
echo "  KinD clusters: $(kind get clusters 2>/dev/null | wc -l | tr -d ' ')"
echo "  Running containers: $(${CONTAINER_CMD} ps --format '{{.Names}}' | grep -E "(${KEYCLOAK_CONTAINER_NAME}|${CLUSTER_NAME})" 2>/dev/null | wc -l | tr -d ' ')"

if [ "$CLEANUP_CONTAINERS" = false ] || [ "$CLEANUP_CLUSTER" = false ]; then
    echo ""
    log_inf "For complete cleanup, run:"
    echo "  $0 --keycloak --cluster --hosts"
fi

echo ""
