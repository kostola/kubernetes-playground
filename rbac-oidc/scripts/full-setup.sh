#!/bin/bash

set -e

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

${SCRIPT_DIR}/generate-certs.sh
${SCRIPT_DIR}/start-keycloak.sh
${SCRIPT_DIR}/start-kind-cluster.sh

${SCRIPT_DIR}/kubectl-oidc.sh alice password123
${SCRIPT_DIR}/kubectl-oidc.sh bob password123
${SCRIPT_DIR}/kubectl-oidc.sh charlie password123
