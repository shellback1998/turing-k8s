# Equipment Monitor Troubleshooting

## Start Here

Run:

    equipment-monitor health

Then:

    equipment-monitor pods

For a deeper test:

    equipment-monitor verify

## Check Prerequisites

    equipment-monitor check

This checks:

- kubectl
- Kubernetes connectivity
- private registry
- ARM64 build node
- required manifests

## Show Status

    equipment-monitor status

## Show Pod Placement

    equipment-monitor pods

This is particularly important for architecture troubleshooting.

Equipment Monitor application pods should run on ARM64 Turing nodes.

## ImagePullBackOff

Inspect pods:

    equipment-monitor pods

Then inspect the affected pod:

    sudo kubectl describe pod <pod-name> -n equipment-monitor

Confirm the image exists:

    curl -s http://192.168.8.191:5000/v2/equipment-monitor/tags/list

## Architecture Problems

Equipment Monitor is built for ARM64.

Confirm the Deployment contains:

    nodeSelector:
      kubernetes.io/arch: arm64

Inspect placement:

    equipment-monitor pods

Application pods should not run on amd64 k8s-manager.

## Application Logs

    equipment-monitor logs

Follow logs:

    equipment-monitor logs --follow

## Redis Logs

    equipment-monitor logs redis

Follow Redis logs:

    equipment-monitor logs redis --follow

## Kubernetes Events

    equipment-monitor events

Events are useful for diagnosing:

- scheduling failures
- image pulls
- probe failures
- container restarts

## Detailed Resource Information

    equipment-monitor describe

## Configuration

    equipment-monitor config

## Tailscale

Display URLs:

    equipment-monitor urls

Inspect Services:

    sudo kubectl get svc -n equipment-monitor

Expected Tailscale Service:

    equipment-monitor-tailscale

Type:

    LoadBalancer

## Test Internal Service Manually

Create a temporary curl pod:

    sudo kubectl run equipment-test \
      -n equipment-monitor \
      --restart=Never \
      --image=curlimages/curl \
      --command -- \
      curl -sS http://equipment-monitor/health

Read output:

    sudo kubectl logs -n equipment-monitor equipment-test

Delete it:

    sudo kubectl delete pod equipment-test -n equipment-monitor

Normally use:

    equipment-monitor verify

instead, because it automates this process.

## Restart Application

    equipment-monitor restart

This performs a rolling restart.

## Scale Application

    equipment-monitor scale 5

Valid CLI range:

    1-20

## Registry Verification

List repositories:

    curl -s http://192.168.8.191:5000/v2/_catalog

List Equipment Monitor tags:

    curl -s http://192.168.8.191:5000/v2/equipment-monitor/tags/list

## Rebuild Image

    equipment-monitor build 1.1

The build occurs on turing-node01 and is pushed to the private registry.

## Safe Cleanup

    equipment-monitor destroy

The command requires typing:

    DESTROY

before deleting the dedicated equipment-monitor namespace.

It never deletes the default namespace.

