# Equipment Monitor Architecture

## High-Level Flow

    Tailscale Device
          |
          v
    Tailscale Network
          |
          v
    equipment-monitor-tailscale
          |
          v
    Kubernetes Service
          |
          +-----------------------+
          |           |           |
          v           v           v
        Pod 1       Pod 2       Pod 3
          \           |           /
           \          |          /
            +---------+---------+
                      |
                      v
             equipment-redis
                      |
                      v
                    Redis

## Kubernetes Cluster

Control plane:

    k8s-manager
    Architecture: amd64

Workers:

    turing-node01
    turing-node02
    turing-node03
    turing-node04
    turing-node05
    turing-node06
    turing-node07

Worker architecture:

    arm64

## Container Registry

Private registry:

    192.168.8.191:5000

The registry runs on turing-node01.

Equipment Monitor image:

    192.168.8.191:5000/equipment-monitor:1.0

## ARM64 Build Architecture

Because k8s-manager is amd64 and the Turing Pi workers are arm64, application
images are built directly on turing-node01.

Pipeline:

    k8s-manager source
           |
           | SCP
           v
    turing-node01
           |
           | docker build
           v
      ARM64 image
           |
           | docker push
           v
    Private Registry
           |
           | image pull
           v
    Turing Pi K3s Workers

## Namespace

All Equipment Monitor Kubernetes resources use:

    equipment-monitor

This provides isolation and allows safe application cleanup without touching
the Kubernetes default namespace.

## ConfigMap

The application uses:

    equipment-monitor-config

Configuration includes:

- APP_NAME
- SITE_NAME
- REDIS_HOST
- REDIS_PORT

Secrets must not be stored in the ConfigMap.

## Application Deployment

Deployment:

    equipment-monitor

Default replicas:

    3

Replica count can be changed through:

    equipment-monitor deploy --replicas N

or:

    equipment-monitor scale N

Allowed CLI range:

    1 through 20

## Architecture-Aware Scheduling

The application image is ARM64.

The Deployment therefore contains:

    nodeSelector:
      kubernetes.io/arch: arm64

This prevents Kubernetes from scheduling the application onto the amd64
k8s-manager node.

## Redis

Deployment:

    equipment-redis

Service:

    equipment-redis

Port:

    6379

Redis provides shared state across application replicas.

## Kubernetes Services

Internal application Service:

    equipment-monitor

Redis Service:

    equipment-redis

External Tailscale Service:

    equipment-monitor-tailscale

## Tailscale

The Tailscale Kubernetes Operator creates a tailnet-accessible LoadBalancer.

Requested hostname:

    equipment-monitor

Short URL:

    http://equipment-monitor

Use:

    equipment-monitor urls

to discover the current full DNS name and Tailscale IP.

## Health Architecture

Application endpoint:

    /health

Kubernetes uses this endpoint for:

- readiness checking
- liveness checking

The management CLI adds:

    equipment-monitor health
    equipment-monitor verify

`verify` performs an actual HTTP request through the Kubernetes Service.

