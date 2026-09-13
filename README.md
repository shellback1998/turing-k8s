# Turing Pi Kubernetes Lab

This repository documents my Kubernetes and K3s learning environment.

The Kubernetes control plane runs on a dedicated Ubuntu VM named
`k8s-manager`. Turing Pi nodes will be added later as Kubernetes worker
nodes.

## Environment

- Kubernetes distribution: K3s
- Control plane: k8s-manager
- Control-plane operating system: Ubuntu 22.04 LTS
- Control-plane LAN IP: 192.168.8.115
- Container runtime: containerd
- Kubernetes manifests are managed declaratively with YAML
- Git is used for version control
- GitHub repository: shellback1998/turing-k8s

## Repository Structure

```text
k8s-lab/
├── .gitignore
├── README.md
└── labs/
    └── 01-hello-k8s/
        ├── deployment.yaml
        └── service.yaml