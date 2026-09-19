# Lab 08 Learning Notes

## Concepts Practiced

Lab 08 combines several Kubernetes and container concepts into one application.

### Namespaces

A dedicated namespace isolates the application:

    equipment-monitor

This also makes cleanup safer.

### Deployments

Deployments maintain the desired number of application pods.

Equipment Monitor defaults to three replicas.

### Replica Scaling

The CLI supports:

    equipment-monitor deploy --replicas N
    equipment-monitor deploy -r N
    equipment-monitor scale N

This allows replica count to be changed without editing YAML.

### Services

Services provide stable networking even though individual pod names and IP
addresses change.

### ConfigMaps

ConfigMaps separate non-secret configuration from the container image.

### Redis Shared State

Multiple application pods cannot rely on local process memory for shared state.

Redis provides one common state store used by all replicas.

### Readiness Probes

Readiness determines whether a pod should receive Service traffic.

A Running pod is not necessarily Ready.

### Liveness Probes

Liveness allows Kubernetes to detect and restart an unhealthy application
container.

### Resource Requests and Limits

The manifests define CPU and memory requests and limits.

Requests help Kubernetes schedule workloads.

Limits constrain resource consumption.

### Private Container Registry

Images are stored at:

    192.168.8.191:5000

The registry allows the cluster to pull locally built application images.

### ARM64 Versus AMD64

An important real-world issue occurred during this lab.

The application image was built on ARM64 turing-node01.

Initially, Kubernetes scheduled:

- two application pods onto ARM64 Turing nodes
- one application pod onto amd64 k8s-manager

The ARM64 pods started successfully.

The pod scheduled on k8s-manager failed.

The fix was to add:

    nodeSelector:
      kubernetes.io/arch: arm64

This taught an important distinction:

Kubernetes scheduling does not automatically guarantee that a container image
is compatible with the selected node architecture.

### Rolling Updates

Changing the Deployment pod template caused Kubernetes to create a new
ReplicaSet and gradually replace the old pods.

During the nodeSelector correction, old pods moved through Terminating and
Completed while new pods became Ready.

### Internal Application Testing

A temporary curl pod was used to test:

    http://equipment-monitor/health

The response verified:

- Kubernetes DNS
- Service routing
- application health
- Redis connectivity

### Tailscale Operator

The Tailscale Kubernetes Operator exposes the application without requiring a
traditional public Internet ingress.

The application can be reached from authorized tailnet devices.

### CLI Automation

Manual Kubernetes operations were converted into the reusable:

    equipment-monitor

management CLI.

The CLI intentionally exposes learning through:

    equipment-monitor explain <topic>

Available concepts include:

- build
- deploy
- scale
- node-selector
- tailscale
- redis
- configmap
- probes
- service
- restart
- verify
- destroy

### Health Versus Verify

`health` inspects Kubernetes component state.

`verify` goes further by making a real HTTP request through the Kubernetes
Service.

An early verification returned only 2/3 Ready even though all pods became
healthy shortly afterward.

The CLI was improved so `verify` now waits for rollout readiness before making
its health judgment.

This avoids false failures during brief readiness transitions.

## Automation Improvements Introduced

Lab 08 adds several improvements to the management pattern used in earlier
labs:

- configurable replica counts
- input validation
- ARM64 remote build automation
- image tagging
- private registry push automation
- prerequisite checking
- automatic rollout waiting
- end-to-end verification
- Tailscale URL discovery
- effective configuration inspection
- learning-oriented explain commands
- safe namespace-based destroy
- temporary verification-pod cleanup

## Standard CLI Pattern for Future Labs

Future Kubernetes applications should aim to provide:

    <app> build [TAG]
    <app> check
    <app> deploy
    <app> deploy --replicas N
    <app> deploy -r N
    <app> destroy
    <app> status
    <app> pods
    <app> logs
    <app> logs <component>
    <app> logs --follow
    <app> scale N
    <app> restart
    <app> urls
    <app> health
    <app> verify
    <app> config
    <app> describe
    <app> events
    <app> explain <topic>
    <app> install
    <app> version
    <app> --help

## Git Rules

Before committing:

    git status

Stage only intended files.

Avoid:

    git add .

Do not commit Kubernetes Secrets, passwords, credentials, tokens, or other
sensitive data.

