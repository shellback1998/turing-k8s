# Lab 06 — Multi-Node Kubernetes Voting Application

## Overview

This lab deploys a complete multi-container Voting Application to a seven-node Turing Pi Kubernetes/K3s cluster.

The application demonstrates several important Kubernetes concepts working together:

- Namespaces
- Deployments
- Services
- Configurable resource limits
- Kubernetes Secrets
- Persistent storage
- PersistentVolumeClaims
- Ingress
- Traefik
- Kubernetes DNS
- Multi-node scheduling
- ARM64 and AMD64 workloads
- Multi-architecture container images
- Self-healing
- Pod replacement
- Cross-node networking
- Persistent application data

The application consists of five primary components:

1. Vote frontend
2. Redis
3. Worker
4. PostgreSQL
5. Result frontend

---

# Architecture

The application data flow is:

```text
User
 |
 v
Traefik Ingress
 |
 +----------------------+
 |                      |
 v                      v
Vote                  Result
 |                      |
 v                      |
Redis                    |
 |                      |
 v                      |
Worker                   |
 |                      |
 +----------+-----------+
            |
            v
        PostgreSQL
```

Votes are submitted through the Vote frontend.

The Vote application places each vote into Redis.

The Worker retrieves votes from Redis and writes them into PostgreSQL.

The Result application queries PostgreSQL and displays the current results.

---

# Kubernetes Cluster

The lab runs on a seven-node mixed-architecture K3s cluster.

```text
k8s-manager      AMD64     Control Plane
turing-node02    ARM64     Worker
turing-node03    ARM64     Worker
turing-node04    ARM64     Worker
turing-node05    ARM64     Worker
turing-node06    ARM64     Worker
turing-node07    ARM64     Worker
```

Kubernetes can verify the nodes with:

```bash
sudo kubectl get nodes -o wide
```

Architecture labels can be displayed with:

```bash
sudo kubectl get nodes --show-labels
```

Kubernetes automatically provides architecture labels such as:

```text
kubernetes.io/arch=amd64
kubernetes.io/arch=arm64
```

These labels are used later to control workload scheduling.

---

# Namespace

All application components run inside the dedicated namespace:

```text
voting-app
```

Manifest:

```text
namespace.yaml
```

Verify the namespace:

```bash
sudo kubectl get namespaces
```

---

# Redis

Redis acts as the temporary message queue between the Vote frontend and the Worker.

Manifest:

```text
redis.yaml
```

Redis listens internally on:

```text
6379
```

A Kubernetes ClusterIP Service named:

```text
redis
```

allows applications to reach Redis using Kubernetes DNS.

For example, the Vote and Worker applications can simply connect to:

```text
redis:6379
```

instead of knowing the Redis Pod's IP address.

---

# PostgreSQL

PostgreSQL stores the permanent voting data.

Manifest:

```text
postgres.yaml
```

The PostgreSQL Kubernetes Service is named:

```text
db
```

Applications therefore connect using:

```text
db:5432
```

instead of a Pod IP.

The application database is:

```text
votes
```

---

# PostgreSQL Secret

PostgreSQL credentials are stored in a Kubernetes Secret.

Local manifest:

```text
postgres-secret.yaml
```

IMPORTANT:

This file contains credentials and MUST NOT be committed to Git or GitHub.

The repository `.gitignore` excludes:

```text
labs/06-voting-app/postgres-secret.yaml
```

Never place the actual PostgreSQL password in this README, source code, Git commits, or GitHub.

Verify that the Secret exists without displaying its sensitive values:

```bash
sudo kubectl get secret postgres-secret -n voting-app
```

---

# Persistent Storage

PostgreSQL uses a PersistentVolumeClaim named:

```text
postgres-pvc
```

The requested storage size is:

```text
1Gi
```

The K3s cluster uses the:

```text
local-path
```

StorageClass.

Check the PVC:

```bash
sudo kubectl get pvc -n voting-app
```

Check PersistentVolumes:

```bash
sudo kubectl get pv
```

Because K3s local-path storage is node-local, the PostgreSQL volume is associated with a particular node.

For this reason, the database should not be casually moved between cluster nodes.

---

# Vote Frontend

Manifest:

```text
vote.yaml
```

Container image:

```text
ghcr.io/shellback1998/voting-app-vote:latest
```

The application listens on:

```text
5000
```

The Kubernetes Service is named:

```text
vote
```

The Vote image was built as a multi-architecture container image supporting:

```text
linux/amd64
linux/arm64
```

This allows the same container image to run on either the AMD64 manager or the ARM64 Turing Pi worker nodes.

---

# Worker

Manifest:

```text
worker.yaml
```

Container image:

```text
ghcr.io/shellback1998/voting-app-worker:latest
```

The Worker does not require a Kubernetes Service because other applications do not initiate connections to it.

The Worker performs the following process:

```text
Redis
  |
  v
Worker
  |
  v
PostgreSQL
```

It reads votes from Redis and inserts them into the PostgreSQL `votes` database.

The PostgreSQL password is provided to the Worker through the Kubernetes Secret.

---

# Result Frontend

Manifest:

```text
result.yaml
```

Container image:

```text
ghcr.io/shellback1998/voting-app-result:latest
```

The Result application listens on:

```text
3000
```

The Kubernetes Service is named:

```text
result
```

Result queries PostgreSQL and displays the current voting totals.

---

# Ingress

Manifest:

```text
ingress.yaml
```

K3s provides Traefik as the Ingress Controller.

Two hostnames are configured:

```text
vote.turing.local
result.turing.local
```

Traffic is routed as follows:

```text
vote.turing.local
        |
        v
     Traefik
        |
        v
   vote Service
        |
        v
    Vote Pod
```

and:

```text
result.turing.local
        |
        v
     Traefik
        |
        v
  result Service
        |
        v
   Result Pod
```

Check the Ingress:

```bash
sudo kubectl get ingress -n voting-app
```

Test Vote without configuring local DNS:

```bash
curl -i \
  -H "Host: vote.turing.local" \
  http://192.168.8.115
```

Test Result:

```bash
curl -i \
  -H "Host: result.turing.local" \
  http://192.168.8.115
```

---

# Multi-Node Scheduling

The custom application containers were built for both AMD64 and ARM64.

To move application workloads onto the Turing Pi ARM64 workers, the following node selector was added to the Vote, Worker, and Result Deployments:

```yaml
nodeSelector:
  kubernetes.io/arch: arm64
```

This does NOT select a particular Raspberry Pi.

Instead, it tells the Kubernetes scheduler:

```text
This Pod may run on any node with the ARM64 architecture label.
```

The scheduler then chooses an appropriate ARM64 worker.

During this lab, Kubernetes distributed the application across multiple physical machines.

An observed configuration was:

```text
k8s-manager      PostgreSQL
k8s-manager      Redis

turing-node02    Vote
turing-node03    Worker
turing-node05    Result
```

Later, during failure testing, Kubernetes automatically moved Vote to:

```text
turing-node06
```

Actual placement can change because Pods are designed to be replaceable.

View current placement with:

```bash
sudo kubectl get pods -n voting-app -o wide
```

---

# Cross-Node Networking Test

A Cats vote was submitted through Traefik while the application was distributed across the cluster.

The request traveled approximately as follows:

```text
Client
  |
  v
Traefik
  |
  v
Vote
turing-node02
  |
  v
Redis
k8s-manager
  |
  v
Worker
turing-node03
  |
  v
PostgreSQL
k8s-manager
```

The vote was submitted with:

```bash
curl -s -X POST \
  -H "Host: vote.turing.local" \
  -d "vote=Cats" \
  http://192.168.8.115
```

PostgreSQL was queried with:

```bash
sudo kubectl exec -n voting-app deployment/db -- \
  psql -U postgres -d votes \
  -c "SELECT * FROM votes ORDER BY id;"
```

The database contained:

```text
id | vote
---+-----
1  | Dogs
2  | Cats
```

This demonstrated successful application communication across multiple physical Kubernetes nodes.

---

# Kubernetes Self-Healing Test

The running Vote Pod was deliberately deleted.

First the Pod was identified:

```bash
sudo kubectl get pods -n voting-app -o wide | grep vote
```

The original Pod was running on:

```text
turing-node02
```

The Pod was deliberately deleted:

```bash
sudo kubectl delete pod <vote-pod-name> -n voting-app
```

No replacement Pod was manually created.

The Vote Deployment specifies:

```yaml
replicas: 1
```

Kubernetes detected that the desired state was no longer satisfied and automatically created a replacement Pod.

The replacement Vote Pod was scheduled on:

```text
turing-node06
```

The replacement received:

- A new Pod name
- A new Pod IP
- A different physical node

However, the Kubernetes Service remained unchanged.

The application was then tested through Traefik:

```bash
curl -i \
  -H "Host: vote.turing.local" \
  http://192.168.8.115
```

The application returned:

```text
HTTP/1.1 200 OK
```

This demonstrated Kubernetes self-healing.

---

# Pods Are Disposable

One of the most important lessons from this lab is:

```text
Pods are disposable.
```

Applications should not depend on:

- Pod names
- Pod IP addresses
- A particular Pod instance

Instead, Kubernetes Services provide stable network identities.

For example:

```text
redis
db
vote
result
```

remain stable even when the Pods behind those Services are replaced.

---

# Persistent Data vs Disposable Pods

The Vote Pod was destroyed during failure testing.

After Kubernetes recreated the Vote Pod, PostgreSQL was queried again:

```bash
sudo kubectl exec -n voting-app deployment/db -- \
  psql -U postgres -d votes \
  -c "SELECT * FROM votes ORDER BY id;"
```

The existing voting data was still present:

```text
1 | Dogs
2 | Cats
```

This demonstrates an important Kubernetes distinction:

```text
Application Pods
      =
Disposable

PersistentVolume
      =
Persistent application data
```

---

# Useful Commands

View everything in the namespace:

```bash
sudo kubectl get all -n voting-app
```

View Pods and physical node placement:

```bash
sudo kubectl get pods -n voting-app -o wide
```

View Services:

```bash
sudo kubectl get services -n voting-app
```

View Ingress:

```bash
sudo kubectl get ingress -n voting-app
```

View PVCs:

```bash
sudo kubectl get pvc -n voting-app
```

View PersistentVolumes:

```bash
sudo kubectl get pv
```

View a Deployment:

```bash
sudo kubectl describe deployment vote -n voting-app
```

View Pod logs:

```bash
sudo kubectl logs -n voting-app deployment/vote
```

Worker logs:

```bash
sudo kubectl logs -n voting-app deployment/worker
```

Result logs:

```bash
sudo kubectl logs -n voting-app deployment/result
```

Redis logs:

```bash
sudo kubectl logs -n voting-app deployment/redis
```

PostgreSQL logs:

```bash
sudo kubectl logs -n voting-app deployment/db
```

---

# Deploying the Lab

Create the namespace first:

```bash
sudo kubectl apply -f labs/06-voting-app/namespace.yaml
```

Create the PostgreSQL Secret from the protected local Secret manifest:

```bash
sudo kubectl apply -f labs/06-voting-app/postgres-secret.yaml
```

Then deploy the application components:

```bash
sudo kubectl apply -f labs/06-voting-app/redis.yaml

sudo kubectl apply -f labs/06-voting-app/postgres.yaml

sudo kubectl apply -f labs/06-voting-app/vote.yaml

sudo kubectl apply -f labs/06-voting-app/worker.yaml

sudo kubectl apply -f labs/06-voting-app/result.yaml

sudo kubectl apply -f labs/06-voting-app/ingress.yaml
```

Verify:

```bash
sudo kubectl get pods -n voting-app -o wide
```

---

# Safe Cleanup

The entire lab can eventually be removed by deleting its namespace:

```bash
sudo kubectl delete namespace voting-app
```

WARNING:

Deleting the namespace also removes namespaced application resources, including the PostgreSQL PersistentVolumeClaim.

Do not run the cleanup command if the voting data needs to be preserved.

Before cleanup, inspect the resources:

```bash
sudo kubectl get all -n voting-app

sudo kubectl get pvc -n voting-app
```

For learning and troubleshooting, keeping the application deployed is useful because it provides a working multi-node Kubernetes application for future experiments.

---

# Git and GitHub Safety

The Kubernetes manifests and documentation belong in Git.

The PostgreSQL Secret does NOT.

Before every commit:

```bash
git status
```

Verify that this file is never staged:

```text
labs/06-voting-app/postgres-secret.yaml
```

The `.gitignore` protects this file.

Never use commands such as:

```bash
git add -f labs/06-voting-app/postgres-secret.yaml
```

because `-f` would override the ignore protection.

---

# Key Lessons

This lab demonstrated that Kubernetes can:

- Run an application across multiple physical machines
- Run multi-architecture container images
- Schedule workloads according to node architecture
- Provide stable DNS names for changing Pods
- Route traffic through Services
- Route external HTTP traffic through Ingress
- Allow Pods on different nodes to communicate
- Store application data persistently
- Inject credentials through Kubernetes Secrets
- Automatically replace failed Pods
- Reschedule workloads onto another physical node
- Maintain application availability while Pods are replaced

Most importantly:

```text
You describe the desired state.

Kubernetes continuously works to make
the actual state match the desired state.
```

That desired-state model is one of the fundamental ideas behind Kubernetes.