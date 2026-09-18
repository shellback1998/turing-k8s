# Turing Pi Cluster Quick Reference

A practical command reference for the Turing Pi lab environment: cluster
helper tools, Kubernetes/K3s, the Voting App, Tailscale, Ansible,
Git/GitHub, Docker, SSH, and common troubleshooting.

> **Environment note:** Cluster helper commands are primarily used on
> `turing-node01`; Kubernetes/K3s and `voting-app` commands are used on
> `k8s-manager`; Ansible commands are primarily used on
> `turing-manager`.

> **Security rule:** Never commit Kubernetes Secret manifests,
> passwords, tokens, private keys, or other credentials to Git/GitHub.

------------------------------------------------------------------------

## 1. Cluster Tools

These helper commands manage and inspect the Turing Pi nodes.

  Command                   Purpose
  ------------------------- ----------------------------------
  `cluster-status`          Show status of cluster nodes
  `cluster-health`          Run cluster health checks
  `cluster-disk`            Check disk usage
  `cluster-docker-status`   Check Docker status across nodes
  `cluster-update-check`    Check for available updates
  `cluster-run <command>`   Run a command across nodes
  `cluster-reboot`          Reboot cluster nodes
  `cluster-stop`            Shut down cluster nodes
  `cluster-vscode-stop`     Stop VS Code remote processes
  `cluster-backup-config`   Back up cluster configuration
  `cluster-backup-list`     List backups
  `cluster-backup-clean`    Clean old backups
  `cluster-clean`           General cluster cleanup

### Common examples

``` bash
cluster-status
cluster-health
cluster-run uptime
cluster-disk
```

------------------------------------------------------------------------

## 2. Kubernetes / K3s

Run these primarily from `k8s-manager`.

### Cluster and nodes

``` bash
sudo kubectl get nodes
sudo kubectl get nodes -o wide
sudo kubectl get namespaces
sudo kubectl get all -A
```

### Pods

``` bash
sudo kubectl get pods -A
sudo kubectl get pods -n voting-app
sudo kubectl get pods -n voting-app -o wide
```

### Services

``` bash
sudo kubectl get svc -A
sudo kubectl get svc -n voting-app
```

### Deployments

``` bash
sudo kubectl get deployments -n voting-app
sudo kubectl rollout status deployment/vote -n voting-app
```

### Everything in the Voting App namespace

``` bash
sudo kubectl get all -n voting-app
```

### Logs

``` bash
sudo kubectl logs -n voting-app deployment/vote
sudo kubectl logs -n voting-app deployment/result
sudo kubectl logs -n voting-app deployment/worker
```

Follow logs continuously:

``` bash
sudo kubectl logs -f -n voting-app deployment/vote
```

### Troubleshooting

``` bash
sudo kubectl describe pod <pod-name> -n voting-app
sudo kubectl get events -n voting-app
sudo kubectl get events -n voting-app --sort-by=.lastTimestamp
```

### Apply and validate manifests

``` bash
sudo kubectl apply -f <file.yaml>
sudo kubectl apply --dry-run=client -f <file.yaml>
```

### Namespace operations

``` bash
sudo kubectl get namespace voting-app
sudo kubectl delete namespace voting-app
```

------------------------------------------------------------------------

## 3. Voting App Management Tool

The `voting-app` helper is installed globally at
`/usr/local/bin/voting-app`, with its tracked source in:

``` text
~/k8s-lab/tools/voting-app
```

### Main commands

``` bash
voting-app
voting-app status
voting-app urls
voting-app pods
voting-app logs vote
voting-app logs result
voting-app logs worker
voting-app deploy
voting-app destroy
voting-app help
```

### Install or update the global command

After editing the tracked source:

``` bash
cd ~/k8s-lab
./tools/voting-app install
```

### Tailscale access

The rebuilt Vote UI is intended to be reachable from Tailscale-connected
devices at:

``` text
http://voting-app
```

The full Tailscale DNS name is:

``` text
http://voting-app.tail5739b8.ts.net
```

The `voting-app deploy` workflow recreates the namespace, runtime
PostgreSQL Secret, PostgreSQL, Redis, Vote, Result, Worker, and the
Tailscale LoadBalancer service.

------------------------------------------------------------------------

## 4. Tailscale

### Show tailnet devices

``` bash
tailscale status
```

### Show this machine's Tailscale IPv4 address

``` bash
tailscale ip -4
```

### Test connectivity

``` bash
tailscale ping turing-manager
tailscale ping k8s-manager
tailscale ping visitor-counter
tailscale ping voting-app
```

### Useful Kubernetes checks for Tailscale

``` bash
sudo kubectl get svc -A | grep -i tailscale
sudo kubectl get pods -A | grep -i tailscale
```

Inspect a Tailscale LoadBalancer Service:

``` bash
sudo kubectl get svc voting-app-tailscale -n voting-app -o yaml
```

------------------------------------------------------------------------

## 5. Ansible

Run these primarily from `turing-manager`.

### Inventory

``` bash
ansible all --list-hosts
ansible turing_nodes --list-hosts
```

### Connectivity

``` bash
ansible turing_nodes -m ping
```

### Run commands on all Turing nodes

``` bash
ansible turing_nodes -a "uptime"
ansible turing_nodes -a "hostname"
ansible turing_nodes -a "df -h"
```

### Playbooks

``` bash
ansible-playbook baseline.yml
ansible-playbook --syntax-check baseline.yml
ansible-playbook baseline.yml --check
```

### Ansible helper

``` bash
ansible-tools
```

Use `ansible-tools` for the helper workflow you built around the Ansible
lab.

------------------------------------------------------------------------

## 6. Git / GitHub

The normal lab checkpoint workflow is:

``` bash
git status
git diff
git add <file>
git status
git commit -m "Describe the completed change"
git push
git status
```

### Compact status

``` bash
git status --short
```

### Undo staging without deleting the file

``` bash
git restore --staged <file>
```

### Expected clean ending

``` text
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

### Security check before every commit

Confirm that Secret files and credentials are not staged:

``` bash
git status
```

For the Voting App, `postgres-secret.yaml` should remain outside Git.

------------------------------------------------------------------------

## 7. Docker

### Running containers

``` bash
docker ps
docker ps -a
```

### Images

``` bash
docker images
```

### Docker Compose

``` bash
docker compose up -d
docker compose ps
docker compose logs
docker compose down
```

### Follow Compose logs

``` bash
docker compose logs -f
```

### Build an image

``` bash
docker build -t <image-name> .
```

### Stop and remove a container

``` bash
docker stop <container>
docker rm <container>
```

Use prune commands carefully; do not remove images or volumes unless you
intend to.

------------------------------------------------------------------------

## 8. SSH / Remote Access

### Connect to a host

``` bash
ssh piadmin@<ip-address>
```

With configured SSH aliases:

``` bash
ssh turing
ssh turing02
ssh turing03
```

### Copy a file from a remote system

``` bash
scp piadmin@<host>:/remote/path/file .
```

### Copy a directory

``` bash
scp -r piadmin@<host>:/remote/path/directory .
```

VS Code Remote SSH is the preferred workflow for editing files on the
lab machines.

------------------------------------------------------------------------

## 9. Quick Health Check

For a fast check of the environment:

``` bash
cluster-status
cluster-health
tailscale status
sudo kubectl get nodes -o wide
sudo kubectl get pods -A
voting-app
```

For Ansible:

``` bash
ansible turing_nodes -m ping
```

------------------------------------------------------------------------

## 10. Four Commands to Remember

These give a quick view across the main layers of the lab:

``` bash
cluster-status
ansible-tools
sudo kubectl get all -A
voting-app
```

Think of them as:

``` text
Cluster hardware
      ↓
Ansible automation
      ↓
Kubernetes / K3s
      ↓
Applications
```

------------------------------------------------------------------------

## 11. End-of-Session Checklist

1.  Check Git:

    ``` bash
    git status
    ```

2.  Commit completed lab work only.

3.  Confirm Secrets and credentials are not tracked.

4.  Push completed checkpoints:

    ``` bash
    git push
    ```

5.  Check Kubernetes workloads:

    ``` bash
    sudo kubectl get pods -A
    ```

6.  Clean up temporary lab resources when appropriate.

7.  If shutting down the physical cluster, use the cluster helper
    workflow rather than abruptly removing power.

------------------------------------------------------------------------

## 12. Important Paths

``` text
~/k8s-lab/                       Kubernetes learning repository
~/k8s-lab/labs/06-voting-app/   Voting App manifests
~/k8s-lab/tools/                 Lab helper commands
~/k8s-lab/tools/voting-app      Voting App management source
/usr/local/bin/voting-app       Installed Voting App command
```

### Voting App tracked manifests

``` text
labs/06-voting-app/
├── README.md
├── ingress.yaml
├── namespace.yaml
├── postgres.yaml
├── redis.yaml
├── result.yaml
├── tailscale.yaml
├── vote.yaml
└── worker.yaml
```

`postgres-secret.yaml` is intentionally not part of the tracked manifest
list.

------------------------------------------------------------------------

*Updated September 18, 2026.*
