package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

// ANSI color codes for terminal output
const (
	ColorReset  = "\033[0m"
	ColorYellow = "\033[33m"
)

// K8sClient wraps the Kubernetes client and provides high-level operations
type K8sClient struct {
	clientset    *kubernetes.Clientset
	podName      string
	podNamespace string
	nodeName     string
}

// NewK8sClient creates a new Kubernetes client using in-cluster configuration
func NewK8sClient() (*K8sClient, error) {
	config, err := rest.InClusterConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to get in-cluster config: %w", err)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create clientset: %w", err)
	}

	// Get pod metadata from Downward API environment variables
	podName := os.Getenv("POD_NAME")
	podNamespace := os.Getenv("POD_NAMESPACE")
	nodeName := os.Getenv("NODE_NAME")

	return &K8sClient{
		clientset:    clientset,
		podName:      podName,
		podNamespace: podNamespace,
		nodeName:     nodeName,
	}, nil
}

// ListPods retrieves and displays all pods in the specified namespace
func (k *K8sClient) ListPods(namespace string) error {
	pods, err := k.clientset.CoreV1().Pods(namespace).List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		return fmt.Errorf("failed to list pods: %w", err)
	}

	fmt.Printf("Found %d pods in namespace '%s':\n", len(pods.Items), namespace)
	for _, pod := range pods.Items {
		// Check if this is our own pod and highlight it in yellow
		if pod.Name == k.podName && pod.Namespace == k.podNamespace {
			fmt.Printf("%s- %s (Phase: %s) <- THIS IS ME!%s\n",
				ColorYellow, pod.Name, pod.Status.Phase, ColorReset)
		} else {
			fmt.Printf("- %s (Phase: %s)\n", pod.Name, pod.Status.Phase)
		}
	}

	return nil
}

// ListNamespaces retrieves and displays all namespaces in the cluster
func (k *K8sClient) ListNamespaces() error {
	namespaces, err := k.clientset.CoreV1().Namespaces().List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		return fmt.Errorf("failed to list namespaces: %w", err)
	}

	fmt.Printf("Found %d namespaces:\n", len(namespaces.Items))
	for _, ns := range namespaces.Items {
		// Highlight our own namespace in yellow
		if ns.Name == k.podNamespace {
			fmt.Printf("%s- %s (Phase: %s) <- MY NAMESPACE%s\n",
				ColorYellow, ns.Name, ns.Status.Phase, ColorReset)
		} else {
			fmt.Printf("- %s (Phase: %s)\n", ns.Name, ns.Status.Phase)
		}
	}

	return nil
}

// GetClusterInfo retrieves and displays basic cluster information
func (k *K8sClient) GetClusterInfo() error {
	nodes, err := k.clientset.CoreV1().Nodes().List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		return fmt.Errorf("failed to list nodes: %w", err)
	}

	fmt.Printf("Cluster has %d nodes:\n", len(nodes.Items))
	for _, node := range nodes.Items {
		ready := "NotReady"
		for _, condition := range node.Status.Conditions {
			if condition.Type == "Ready" && condition.Status == "True" {
				ready = "Ready"
				break
			}
		}

		// Highlight the node we're running on in yellow
		if node.Name == k.nodeName {
			fmt.Printf("%s- %s (%s, %s) <- MY NODE%s\n",
				ColorYellow, node.Name, node.Status.NodeInfo.KubeletVersion, ready, ColorReset)
		} else {
			fmt.Printf("- %s (%s, %s)\n", node.Name, node.Status.NodeInfo.KubeletVersion, ready)
		}
	}

	return nil
}

func main() {
	log.Println("Starting Kubernetes API client...")

	client, err := NewK8sClient()
	if err != nil {
		log.Fatalf("Failed to create Kubernetes client: %v", err)
	}

	// Log pod metadata from Downward API
	log.Printf("Pod metadata from Downward API:")
	log.Printf("  Pod Name: %s", client.podName)
	log.Printf("  Pod Namespace: %s", client.podNamespace)
	log.Printf("  Node Name: %s", client.nodeName)

	namespace := os.Getenv("TARGET_NAMESPACE")
	if namespace == "" {
		namespace = "default"
	}

	// Run operations in a loop to demonstrate continuous monitoring
	for {
		log.Println("=== Kubernetes API Information ===")

		if err := client.GetClusterInfo(); err != nil {
			log.Printf("Error getting cluster info: %v", err)
		}

		fmt.Println()

		if err := client.ListNamespaces(); err != nil {
			log.Printf("Error listing namespaces: %v", err)
		}

		fmt.Println()

		if err := client.ListPods(namespace); err != nil {
			log.Printf("Error listing pods: %v", err)
		}

		log.Println("=== End of Information ===")
		log.Println("Waiting 30 seconds before next update...")
		time.Sleep(30 * time.Second)
	}
}
