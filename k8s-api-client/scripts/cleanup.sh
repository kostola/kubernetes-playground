#!/bin/bash

set -e

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

log_info "Cleaning up ${APP_NAME} resources..."

# Ensure we're using the correct context if cluster exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    kubectl config use-context ${KUBECTL_CONTEXT}

    # Delete deployment
    log_info "Deleting deployment..."
    kubectl delete -f "${K8S_MANIFESTS_DIR}/deployment.yaml" --ignore-not-found=true

    # Delete RBAC configuration
    log_info "Deleting RBAC configuration..."
    kubectl delete -f "${K8S_MANIFESTS_DIR}/rbac.yaml" --ignore-not-found=true

    log_success "Kubernetes resources cleanup completed!"
else
    log_info "No KinD cluster '${CLUSTER_NAME}' found, skipping Kubernetes cleanup"
fi

# Clean up container images if requested
if [ "$1" = "--all" ] || [ "$1" = "-a" ]; then
    log_info "Cleaning up container images..."

    if ${CONTAINER_CMD} images | grep -q "${IMAGE_NAME}"; then
        ${CONTAINER_CMD} rmi ${FULL_IMAGE_NAME} 2>/dev/null || true
        log_success "Container image removed"
    else
        log_info "No container image found to remove"
    fi
fi

# Clean up KinD cluster if requested
if [ "$1" = "--cluster" ] || [ "$2" = "--cluster" ]; then
    log_info "Deleting KinD cluster '${CLUSTER_NAME}'..."
    kind delete cluster --name ${CLUSTER_NAME}
    log_success "KinD cluster deleted"
fi

echo ""
echo "Cleanup completed successfully!"
echo ""
echo "Options:"
echo "  --all, -a        Also remove container images"
echo "  --cluster        Also delete the KinD cluster"
