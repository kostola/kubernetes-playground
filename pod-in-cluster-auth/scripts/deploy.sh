#!/bin/bash

set -e

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

check_requirements

log_info "Deploying ${APP_NAME} to Kubernetes..."

# Ensure we're using the correct context
kubectl config use-context ${KUBECTL_CONTEXT}

# Apply RBAC configuration
log_info "Applying RBAC configuration..."
kubectl apply -f "${K8S_MANIFESTS_DIR}/rbac.yaml"

# Apply deployment
log_info "Applying deployment..."
kubectl apply -f "${K8S_MANIFESTS_DIR}/deployment.yaml"

# Wait for deployment to be ready
log_info "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/${APP_NAME} -n ${NAMESPACE}

log_success "Deployment completed successfully!"
echo ""
echo "To view logs, run:"
echo "  kubectl logs -f deployment/${APP_NAME} -n ${NAMESPACE}"
echo ""
echo "To check pod status, run:"
echo "  kubectl get pods -l app=${APP_NAME} -n ${NAMESPACE}"
echo ""
echo "To check all resources, run:"
echo "  kubectl get all -l app=${APP_NAME} -n ${NAMESPACE}"
