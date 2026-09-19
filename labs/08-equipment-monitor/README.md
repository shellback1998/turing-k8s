# Lab 08 — Equipment Monitor

## Overview

Equipment Monitor is a multi-node Kubernetes application built as a learning
project on the Turing Pi K3s cluster.

The lab demonstrates a complete application lifecycle:

Source Code
→ ARM64 Container Build
→ Private Docker Registry
→ Kubernetes
→ Redis
→ Multiple Application Replicas
→ Tailscale

The application displays simulated engineering equipment including pumps,
tanks, and valves.

## Architecture

The application consists of:

- Flask / Gunicorn web application
- Redis shared state service
- Kubernetes Deployment
- Kubernetes ClusterIP Services
- Tailscale LoadBalancer Service
- ConfigMap
- readiness and liveness probes
- CPU and memory resource controls
- ARM64 node scheduling
- configurable application replicas

Default application replicas: 3

## Application URLs

When connected to the Tailscale network:

    http://equipment-monitor

The full Tailscale DNS name and IP can be discovered with:

    equipment-monitor urls

## Management CLI

The primary management interface is:

    equipment-monitor

Common commands:

    equipment-monitor check
    equipment-monitor build 1.0
    equipment-monitor deploy
    equipment-monitor deploy --replicas 3
    equipment-monitor status
    equipment-monitor health
    equipment-monitor verify
    equipment-monitor pods
    equipment-monitor logs
    equipment-monitor logs redis
    equipment-monitor scale 5
    equipment-monitor restart
    equipment-monitor urls
    equipment-monitor config
    equipment-monitor events
    equipment-monitor describe
    equipment-monitor explain
    equipment-monitor destroy

Use:

    equipment-monitor --help

for the complete command reference.

## Build Pipeline

k8s-manager is amd64 while the Turing Pi worker nodes are ARM64.

Application images are therefore built remotely on:

    turing-node01
    192.168.8.191

The build script:

    labs/08-equipment-monitor/build.sh

automates:

1. Build-node validation
2. Temporary build-directory creation
3. Source transfer using SCP
4. ARM64 Docker build
5. Push to the private registry
6. Temporary-file cleanup

Private registry:

    192.168.8.191:5000

Image:

    192.168.8.191:5000/equipment-monitor:1.0

## Directory Structure

    labs/08-equipment-monitor/
    ├── README.md
    ├── build.sh
    ├── app/
    │   ├── Dockerfile
    │   ├── app.py
    │   └── requirements.txt
    ├── docs/
    │   ├── ARCHITECTURE.md
    │   ├── LEARNING.md
    │   └── TROUBLESHOOTING.md
    └── manifests/
        ├── configmap.yaml
        ├── equipment-monitor.yaml
        ├── redis.yaml
        └── tailscale.yaml

Management CLI source:

    tools/equipment-monitor

Installed CLI:

    /usr/local/bin/equipment-monitor

## Verification

Run:

    equipment-monitor verify

This waits for the Kubernetes rollout, validates application replicas, Redis,
the Kubernetes Service and Tailscale, then creates a temporary curl pod and
performs an actual request against:

    http://equipment-monitor/health

The temporary verification pod is deleted automatically.

## Security

Do not commit credentials, passwords, tokens, Kubernetes Secret manifests, or
other sensitive information to Git.

ConfigMaps are for non-secret configuration.

## Git Workflow

Inspect changes before staging:

    git status

Stage only intended files rather than using:

    git add .

Verify staged content before committing.

