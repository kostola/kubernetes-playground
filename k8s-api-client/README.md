# Kubernetes API Client

A simple Go application that demonstrates how to access Kubernetes APIs using a ServiceAccount and the official Kubernetes client-go library.

## Features

- Connects to Kubernetes cluster using in-cluster configuration
- Lists cluster nodes and their status
- Lists all namespaces in the cluster
- Lists pods in a specified namespace (configurable via environment variable)
- Runs continuously, updating information every 30 seconds
- Uses proper RBAC with minimal required permissions

## Project Structure

```
k8s-api-client/
├── main.go                 # Main application code
├── go.mod                  # Go module definition
├── Dockerfile              # Container image configuration
├── k8s/
│   ├── rbac.yaml          # ServiceAccount, ClusterRole, and ClusterRoleBinding
│   └── deployment.yaml    # Kubernetes deployment manifest
├── scripts/
│   ├── config.sh          # Shared configuration and utilities
│   ├── kind-setup.sh      # KinD cluster setup script
│   ├── build.sh           # Container image build script
│   ├── deploy.sh          # Kubernetes deployment script
│   ├── test.sh            # Comprehensive testing script
│   └── cleanup.sh         # Resource cleanup script
└── README.md              # This file
```

## Prerequisites

- Go 1.21 or later
- Container runtime: Podman (preferred) or Docker
- kubectl
- KinD (Kubernetes in Docker)

### Installing Prerequisites

**macOS (using Homebrew):**
```bash
# Install Go, container runtime, kubectl, and KinD
brew install go kubectl kind

# Install Podman (preferred) or Docker
brew install podman
# OR
brew install docker

# If using Docker, start Docker Desktop
# open -a Docker
```

**Linux:**
```bash
# Install Go
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install KinD
go install sigs.k8s.io/kind@latest
```

## Quick Start with KinD

### Option 1: One-Command Test
```bash
cd k8s-api-client
./scripts/test.sh
```

### Option 2: Step by Step

1. **Set up KinD cluster:**
   ```bash
   cd k8s-api-client
   ./scripts/kind-setup.sh
   ```

2. **Build and load container image:**
   ```bash
   ./scripts/build.sh
   ```

3. **Deploy the application:**
   ```bash
   ./scripts/deploy.sh
   ```

4. **View application logs:**
   ```bash
   kubectl logs -f deployment/k8s-api-client
   ```

5. **Check pod status:**
   ```bash
   kubectl get pods -l app=k8s-api-client
   ```

## Manual Setup

### 1. Build the Application

```bash
cd k8s-api-client

# Build Go dependencies
go mod tidy

# Build container image (automatically detects Podman/Docker)
./scripts/build.sh

# Or build manually:
# podman build -t k8s-api-client:latest .
# docker build -t k8s-api-client:latest .
```

### 2. Load Image into KinD (if using KinD)

The build script automatically loads the image into KinD if a cluster exists. For manual loading:

```bash
# For Podman
podman save -o /tmp/k8s-api-client-latest.tar k8s-api-client:latest
kind load image-archive /tmp/k8s-api-client-latest.tar --name k8s-playground

# For Docker
kind load docker-image k8s-api-client:latest --name k8s-playground
```

### 3. Deploy to Kubernetes

```bash
# Apply RBAC configuration
kubectl apply -f k8s/rbac.yaml

# Deploy the application
kubectl apply -f k8s/deployment.yaml
```

## Configuration

### Application Configuration

The application can be configured using environment variables:

- `TARGET_NAMESPACE`: The namespace to monitor for pods (default: "default")

To change the target namespace, edit the `deployment.yaml` file:

```yaml
env:
- name: TARGET_NAMESPACE
  value: "kube-system"  # Change to desired namespace
```

### Script Configuration

All scripts use a shared configuration file (`scripts/config.sh`) that exports:

```bash
# Cluster configuration
CLUSTER_NAME="k8s-playground"
NAMESPACE="default"
APP_NAME="k8s-api-client"
IMAGE_NAME="k8s-api-client"
IMAGE_TAG="latest"

# Container runtime (auto-detected)
CONTAINER_RUNTIME="podman|docker"
CONTAINER_CMD="podman|docker"
```

### Container Runtime Support

The scripts automatically detect and prefer Podman over Docker:

1. **Podman (preferred)**: If available, uses Podman for all container operations
2. **Docker (fallback)**: If Podman is not available, falls back to Docker
3. **Error**: If neither is available, scripts will exit with installation instructions

The detection handles the different ways Podman and Docker load images into KinD:
- **Podman**: Uses `podman save` + `kind load image-archive`
- **Docker**: Uses `kind load docker-image` directly

## RBAC Permissions

The application uses minimal RBAC permissions:

- **ServiceAccount**: `k8s-api-client`
- **ClusterRole**: `k8s-api-client-role`
  - `get`, `list`, `watch` on `pods`, `namespaces`, `nodes`
  - `get`, `list`, `watch` on `events`

## Security Features

- Runs as non-root user (UID 1000)
- Uses read-only root filesystem
- Drops all Linux capabilities
- Prevents privilege escalation
- Resource limits enforced (CPU: 100m, Memory: 128Mi)

## Monitoring and Troubleshooting

### View Application Logs
```bash
kubectl logs -f deployment/k8s-api-client
```

### Check Pod Status
```bash
kubectl get pods -l app=k8s-api-client
kubectl describe pod <pod-name>
```

### Check RBAC Configuration
```bash
kubectl get serviceaccount k8s-api-client
kubectl get clusterrole k8s-api-client-role
kubectl get clusterrolebinding k8s-api-client-binding
```

### Test API Access Manually
```bash
# Get a shell in the pod
kubectl exec -it deployment/k8s-api-client -- sh

# Test API access using curl (requires installing curl first)
apk add curl
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -H "Authorization: Bearer $TOKEN" \
     -k https://kubernetes.default.svc/api/v1/namespaces
```

## Cleanup

To remove all resources:

```bash
# Basic cleanup (removes Kubernetes resources)
./scripts/cleanup.sh

# Full cleanup (removes resources + container images)
./scripts/cleanup.sh --all

# Complete cleanup (removes everything including KinD cluster)
./scripts/cleanup.sh --all --cluster
```

Or manually:

```bash
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/rbac.yaml

# Remove container image
podman rmi k8s-api-client:latest
# or
docker rmi k8s-api-client:latest

# Delete KinD cluster
kind delete cluster --name k8s-playground
```

## Development

### Local Development

For local development outside of Kubernetes:

1. Set up a kubeconfig file pointing to your cluster
2. Modify the code to use `clientcmd.BuildConfigFromFlags()` instead of `rest.InClusterConfig()`
3. Run locally: `go run main.go`

### Extending the Application

The application is structured to be easily extensible. Key areas for enhancement:

- Add more Kubernetes resource monitoring
- Implement metrics collection
- Add health check endpoints
- Implement event watching instead of polling
- Add custom resource support

## Common Issues

1. **Image pull errors**: Ensure you've loaded the image into KinD with `kind load docker-image`
2. **Permission denied**: Check RBAC configuration and ensure ServiceAccount is properly bound
3. **Connection refused**: Verify the cluster is running and kubectl context is correct
4. **Pod not starting**: Check resource limits and node capacity

## References

- [Kubernetes Client-Go Documentation](https://pkg.go.dev/k8s.io/client-go)
- [KinD Documentation](https://kind.sigs.k8s.io/)
- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
