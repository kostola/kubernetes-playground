#!/bin/bash

set -e

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

check_requirements

log_info "Running comprehensive test for ${APP_NAME}..."

# Test 1: Check container runtime
log_info "Testing container runtime detection..."
echo "Detected runtime: ${CONTAINER_RUNTIME}"

# Test 2: Build image
log_info "Testing image build..."
"${SCRIPT_DIR}/build.sh"

# Test 3: Verify image exists
log_info "Verifying image exists..."
if ${CONTAINER_CMD} images | grep -q "${IMAGE_NAME}.*${IMAGE_TAG}"; then
    log_success "Image ${FULL_IMAGE_NAME} found"
else
    log_error "Image ${FULL_IMAGE_NAME} not found"
    exit 1
fi

# Test 4: Setup KinD cluster
log_info "Testing KinD cluster setup..."
"${SCRIPT_DIR}/kind-setup.sh"

# Test 5: Deploy application
log_info "Testing application deployment..."
"${SCRIPT_DIR}/deploy.sh"

# Test 6: Wait for pods to be ready
log_info "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=${APP_NAME} -n ${NAMESPACE} --timeout=120s

# Test 7: Check application logs
log_info "Checking application logs..."
sleep 10  # Wait a bit for the app to generate some logs
kubectl logs deployment/${APP_NAME} -n ${NAMESPACE} --tail=10

# Test 8: Verify API access
log_info "Verifying application is accessing Kubernetes APIs..."
if kubectl logs deployment/${APP_NAME} -n ${NAMESPACE} --tail=50 | grep -q "Found.*nodes\|Found.*namespaces\|Found.*pods"; then
    log_success "Application is successfully accessing Kubernetes APIs"
else
    log_error "Application does not seem to be accessing Kubernetes APIs properly"
    kubectl logs deployment/${APP_NAME} -n ${NAMESPACE} --tail=20
    exit 1
fi

# Test 9: Check RBAC
log_info "Verifying RBAC configuration..."
kubectl get serviceaccount ${APP_NAME} -n ${NAMESPACE}
kubectl get clusterrole ${APP_NAME}-role
kubectl get clusterrolebinding ${APP_NAME}-binding

log_success "All tests passed successfully!"
echo ""
echo "Application is running and accessible. To view live logs:"
echo "  kubectl logs -f deployment/${APP_NAME} -n ${NAMESPACE}"
echo ""
echo "To clean up everything:"
echo "  ./scripts/cleanup.sh --all --cluster"
