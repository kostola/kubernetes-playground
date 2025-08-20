# RBAC with OIDC Authentication Demo

This project demonstrates how to set up Kubernetes Role-Based Access Control (RBAC) using OpenID Connect (OIDC) authentication with a local KinD cluster and Keycloak as the identity provider.

## Overview

The demo showcases a complete OIDC authentication flow where:
- A local **Keycloak** instance serves as the OIDC identity provider
- A **KinD** (Kubernetes in Docker) cluster is configured to authenticate users via OIDC
- **RBAC policies** define different permission levels based on user groups
- Multiple **test users** with different roles demonstrate the authorization in action

## User Roles and Permissions

The demo includes three predefined users with different permission levels:

### 🔴 Cluster Admins (`alice`)
- **Group**: `cluster-admins`
- **Password**: `password123`
- **Permissions**: Full cluster administrative access (uses built-in `cluster-admin` role)

### 🟡 Developers (`bob`)
- **Group**: `developers`
- **Password**: `password123`
- **Permissions**: Can manage workloads but not cluster-level resources
  - Create/manage pods, deployments, services, configmaps, secrets
  - Scale deployments
  - Access logs and exec into pods
  - Manage jobs and cronjobs
  - Read-only access to namespaces and nodes

### 🟢 Viewers (`charlie`)
- **Group**: `viewers`
- **Password**: `password123`
- **Permissions**: Read-only access to most resources
  - View pods, deployments, services, configmaps
  - Access logs (but not exec)
  - View jobs, cronjobs, and metrics

## Quick Start

### Prerequisites

Ensure you have the following tools installed:
- [Docker](https://docs.docker.com/get-docker/) or [Podman](https://podman.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [KinD](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [jq](https://stedolan.github.io/jq/download/)
- [curl](https://curl.se/)
- `envsubst` (part of `gettext` package)

On macOS with Homebrew:
```bash
brew install docker kubectl kind jq gettext
```

### Setup

1. **Run the complete setup**:
   ```bash
   ./scripts/full-setup.sh
   ```

   This script will:
   - Generate TLS certificates for Keycloak
   - Start Keycloak with the demo realm configuration
   - Create and configure a KinD cluster with OIDC support
   - Apply RBAC policies
   - Configure kubectl contexts for all demo users

2. **Apply test resources** (optional):
   ```bash
   kubectl apply -f k8s/test-resources.yaml
   ```

### Testing Different User Permissions

Switch between different user contexts to test RBAC policies:

```bash
# Test as alice (cluster admin)
kubectl config use-context user-alice
kubectl get nodes  # ✅ Should work
kubectl get pods --all-namespaces  # ✅ Should work

# Test as bob (developer)
kubectl config use-context user-bob
kubectl get pods  # ✅ Should work
kubectl create deployment test --image=nginx  # ✅ Should work
kubectl get nodes  # ✅ Should work (read-only)

# Test as charlie (viewer)
kubectl config use-context user-charlie
kubectl get pods  # ✅ Should work
kubectl create deployment test --image=nginx  # ❌ Should fail
kubectl delete pod test-pod  # ❌ Should fail
```

### Accessing Keycloak Admin Console

- **URL**: https://localhost:8443
- **Username**: `admin`
- **Password**: `admin123`
- **Realm**: `kubernetes`

## Project Structure

```
rbac-oidc/
├── keycloak/
│   ├── realm-config.json          # Keycloak realm with users and groups
│   └── kind-oidc-config.tmpl.yaml # KinD cluster configuration template
├── k8s/
│   ├── rbac.yaml                  # RBAC roles and bindings
│   └── test-resources.yaml        # Test workloads for permission testing
├── scripts/
│   ├── full-setup.sh             # Complete setup automation
│   ├── start-keycloak.sh         # Start Keycloak with TLS
│   ├── start-kind-cluster.sh     # Create and configure KinD cluster
│   ├── generate-certs.sh         # Generate TLS certificates
│   ├── kubectl-oidc.sh           # Configure kubectl for OIDC user (accepts username/password)
│   ├── get-token.sh              # Helper to get OIDC tokens
│   ├── config.sh                 # Shared configuration
│   └── cleanup.sh                # Cleanup resources
├── target/                       # Generated files (excluded from git)
│   └── {NAME_PREFIX}/            # Configuration-specific folder
│       ├── certs/                # TLS certificates
│       │   ├── ca.crt            # Certificate Authority certificate
│       │   ├── ca.key            # Certificate Authority private key
│       │   ├── keycloak.crt      # Keycloak certificate
│       │   ├── keycloak.key      # Keycloak private key
│       │   └── keycloak.p12      # Keycloak PKCS12 keystore
│       ├── kind-oidc-config.yaml # Generated KinD configuration
│       └── kubeconfig.yaml       # Exported cluster kubeconfig
└── README.md                     # This file
```

## Key Features Demonstrated

### 🔐 OIDC Integration
- Secure HTTPS communication with custom CA certificates
- Proper OIDC client configuration with groups claim mapping
- Token-based authentication with refresh token support

### 🛡️ RBAC Patterns
- **Group-based authorization** (recommended over user-based)
- **Layered permissions** (cluster-wide + namespace-specific)
- **Principle of least privilege** with role separation
- **Custom roles** tailored to different personas

### 🧪 Testing Framework
- Pre-configured test users for different scenarios
- Sample workloads to test permissions
- Resource quotas and limits for realistic constraints

## Cleanup

The cleanup script provides flexible options for removing different components. Use the `--help` flag to see all available options:

```bash
./scripts/cleanup.sh --help
```

### Quick Cleanup Options

```bash
# Remove only Kubernetes resources and generated files (default)
./scripts/cleanup.sh

# Complete cleanup - remove everything
./scripts/cleanup.sh --keycloak --cluster --hosts

# Remove containers and files, but keep cluster
./scripts/cleanup.sh --keycloak

# Remove cluster and files, but keep containers
./scripts/cleanup.sh --cluster
```

**Complete cleanup** (`--keycloak --cluster --hosts`) will:
- Delete the KinD cluster
- Stop and remove the Keycloak container
- Remove the Docker network
- Remove /etc/hosts entries
- Clean up generated certificates and files

## Advanced Usage

### Customizing Resource Names

You can customize the prefix used for all resources (containers, clusters, networks) by setting the `NAME_PREFIX` environment variable:

```bash
# Use custom prefix for all resources
export NAME_PREFIX="my-demo"
./scripts/full-setup.sh

# This will create:
# - Container: my-demo-keycloak
# - Cluster: my-demo-cluster
# - Network: my-demo
# - Target folder: rbac-oidc/target/my-demo/
```

Generated files for each configuration are organized in separate folders under `target/{NAME_PREFIX}/`:
- `target/my-demo/certs/` - TLS certificates
- `target/my-demo/kind-oidc-config.yaml` - KinD cluster configuration
- `target/my-demo/kubeconfig.yaml` - Cluster kubeconfig

This is useful for:
- Running multiple instances of the demo simultaneously
- Avoiding naming conflicts with existing resources
- Using custom naming conventions
- Keeping configurations isolated and organized

### Getting OIDC Tokens Manually

```bash
# Get tokens for a specific user
./scripts/get-token.sh alice

# Use token with kubectl directly
kubectl --token="$ID_TOKEN" get pods
```

### Customizing RBAC Policies

Edit `k8s/rbac.yaml` to modify permissions or add new roles. Key patterns include:

- **ClusterRole**: Define permissions across the cluster
- **ClusterRoleBinding**: Bind users/groups to cluster roles
- **Role**: Define namespace-specific permissions
- **RoleBinding**: Bind users/groups to namespace roles

### Adding New Users

1. Edit `keycloak/realm-config.json` to add users and groups
2. Restart Keycloak: `./scripts/start-keycloak.sh`
3. Configure kubectl for the new user: `./scripts/kubectl-oidc.sh <username> <password>`
4. Update RBAC policies in `k8s/rbac.yaml` if needed
5. Apply changes: `kubectl apply -f k8s/rbac.yaml`

## Security Considerations

⚠️ **This is a demo setup for learning purposes**. For production use:

- Use proper certificate management (not self-signed)
- Implement secure password policies
- Configure proper network security
- Use production-grade identity providers
- Follow security best practices for RBAC design

## Troubleshooting

### Common Issues

1. **Certificate errors**: Ensure the CA certificate is properly mounted and KinD cluster trusts it
2. **Token expiration**: Tokens expire after 5 minutes; use refresh tokens or re-authenticate
3. **Permission denied**: Check which context you're using with `kubectl config current-context`
4. **Keycloak not accessible**: Verify the container is running and ports are correctly mapped

### Useful Commands

```bash
# Check current kubectl context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Check RBAC permissions for current user
kubectl auth can-i --list

# Verify cluster OIDC configuration
kubectl cluster-info dump | grep oidc
```

## Technologies Used

- **Kubernetes**: Container orchestration platform
- **KinD**: Kubernetes in Docker for local development
- **Keycloak**: Open-source identity and access management
- **OIDC**: OpenID Connect authentication protocol
- **RBAC**: Kubernetes Role-Based Access Control
- **Docker/Podman**: Container runtime
