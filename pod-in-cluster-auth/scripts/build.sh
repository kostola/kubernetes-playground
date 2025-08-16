#!/bin/bash

set -e

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

check_requirements

log_info "Building ${APP_NAME} container image..."

# Build the container image
cd "${PROJECT_ROOT}"
${CONTAINER_CMD} build -t ${FULL_IMAGE_NAME} .

log_success "Container image built successfully: ${FULL_IMAGE_NAME}"

# If KinD cluster exists, load the image into it
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log_info "Loading image into KinD cluster '${CLUSTER_NAME}'..."

    # For Podman, we need to save and load the image differently
    if [ "${CONTAINER_RUNTIME}" = "podman" ]; then
        # Save image to tar and load it with kind
        temp_tar="/tmp/${IMAGE_NAME}-${IMAGE_TAG}.tar"
        podman save -o "${temp_tar}" ${FULL_IMAGE_NAME}
        kind load image-archive "${temp_tar}" --name "${CLUSTER_NAME}"
        rm -f "${temp_tar}"
    else
        # Docker can load directly
        kind load docker-image ${FULL_IMAGE_NAME} --name "${CLUSTER_NAME}"
    fi

    log_success "Image loaded into KinD cluster '${CLUSTER_NAME}'"
else
    log_info "No KinD cluster '${CLUSTER_NAME}' found. Run './scripts/kind-setup.sh' first if you want to test with KinD."
fi
