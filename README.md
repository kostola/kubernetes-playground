# Kubernetes Playground

A collection of Kubernetes projects and examples for learning and experimentation. This repository contains various subprojects that demonstrate different aspects of Kubernetes development, from API client implementations to deployment patterns.

## Subprojects

### [pod-in-cluster-auth](./pod-in-cluster-auth/)
A Go application demonstrating how a pod can connect to the cluster Kubernetes API server using an injected ServiceAccount. The main goal is to show in-cluster authentication patterns and proper RBAC configuration. Also includes examples of using [downward APIs](https://kubernetes.io/docs/concepts/workloads/pods/downward-api/) to inject pod information.

**Technologies**: Go, Kubernetes client-go, KinD
