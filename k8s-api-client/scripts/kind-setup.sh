#!/bin/bash

set -e

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

check_requirements

log_info "Setting up KinD cluster for ${APP_NAME} testing..."

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log_info "KinD cluster '${CLUSTER_NAME}' already exists"
    log_info "Current cluster info:"
    kubectl cluster-info --context ${KUBECTL_CONTEXT}
else
    log_info "Creating KinD cluster '${CLUSTER_NAME}'..."
    kind create cluster --name ${CLUSTER_NAME}
    log_success "Cluster created successfully!"
fi

# Set kubectl context
log_info "Setting kubectl context to ${KUBECTL_CONTEXT}..."
kubectl config use-context ${KUBECTL_CONTEXT}

echo ""
log_success "KinD cluster setup completed!"
echo "Cluster name: ${CLUSTER_NAME}"
echo "Context: ${KUBECTL_CONTEXT}"
echo "Container runtime: ${CONTAINER_RUNTIME}"
echo ""
echo "Next steps:"
echo "1. Build and load the container image: ./scripts/build.sh"
echo "2. Deploy the application: ./scripts/deploy.sh"
echo "3. View logs: kubectl logs -f deployment/${APP_NAME}"
