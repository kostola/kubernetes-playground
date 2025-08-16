#!/bin/bash

# Global configuration for pod-in-cluster-auth scripts

# Cluster configuration
export CLUSTER_NAME="k8s-playground"
export NAMESPACE="default"
export APP_NAME="pod-in-cluster-auth"
export IMAGE_NAME="pod-in-cluster-auth"
export IMAGE_TAG="latest"

# Container runtime detection and configuration
detect_container_runtime() {
    if command -v podman &> /dev/null; then
        export CONTAINER_RUNTIME="podman"
        export CONTAINER_CMD="podman"
        echo "Using Podman as container runtime"
    elif command -v docker &> /dev/null; then
        export CONTAINER_RUNTIME="docker"
        export CONTAINER_CMD="docker"
        echo "Using Docker as container runtime"
    else
        echo "Error: Neither Podman nor Docker is installed"
        echo "Please install one of them:"
        echo "  # Podman (preferred):"
        echo "  brew install podman"
        echo "  # Docker:"
        echo "  brew install docker"
        exit 1
    fi
}

# Initialize container runtime detection
detect_container_runtime

# Derived variables
export FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
export KUBECTL_CONTEXT="kind-${CLUSTER_NAME}"

# Paths
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
export K8S_MANIFESTS_DIR="${PROJECT_ROOT}/k8s"

# Utility functions
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_success() {
    echo "[SUCCESS] $1"
}

# Check if required tools are installed
check_requirements() {
    local missing_tools=()

    if ! command -v kubectl &> /dev/null; then
        missing_tools+=(kubectl)
    fi

    if ! command -v kind &> /dev/null; then
        missing_tools+=(kind)
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install them:"
        echo "  brew install kubectl kind"
        exit 1
    fi
}
