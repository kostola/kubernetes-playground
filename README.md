# Kubernetes Playground

A collection of Kubernetes projects and examples for learning and experimentation. This repository contains various subprojects that demonstrate different aspects of Kubernetes development, from API client implementations to deployment patterns.

## Subprojects

### k8s-api-client
A Go application demonstrating how to use injected ServiceAccount credentials in a Kubernetes deployment to communicate with the Kubernetes API and [downward APIs](https://kubernetes.io/docs/concepts/workloads/pods/downward-api/). Shows in-cluster authentication patterns, proper RBAC configuration, and how to inject pod information through downward APIs.

**Technologies**: Go, Kubernetes client-go, KinD
