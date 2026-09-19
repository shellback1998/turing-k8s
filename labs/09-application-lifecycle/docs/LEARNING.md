# Lab 09 Learning Notes

## Kubernetes Concepts

### Rolling Update

Kubernetes gradually replaces pods from an old ReplicaSet with pods from a new ReplicaSet.

This allows an application to be upgraded without replacing every replica simultaneously.

### ReplicaSet

A Deployment creates ReplicaSets representing different pod-template versions.

Older ReplicaSets allow Kubernetes to restore previous application configurations.

### Revision

A Deployment revision represents a historical pod template.

Revision history is useful, but a revision is not automatically a known-good release.

### Rollback

A rollback restores the pod template from an earlier revision.

The Service remains stable while Kubernetes changes the pods behind it.

### Readiness Probe

Determines whether a pod should receive Service traffic.

A running container is not necessarily ready to serve requests.

### Liveness Probe

Determines whether Kubernetes should restart a container because it appears unhealthy.

Liveness probes should not be so aggressive that brief delays cause unnecessary restarts.

---

## Release Engineering Lessons

### Verify Desired State

Do not trust only a successful command or rollout message.

Verify the actual deployed:

- image
- application version
- replica readiness
- application endpoint

### Keep Declarative Configuration Current

The Kubernetes YAML should represent the intended deployed release.

Otherwise a later `kubectl apply` can unintentionally restore an older configuration.

### Prefer Atomic Release Changes

Values that together identify a release should change together.

For Equipment Monitor:

- image tag
- APP_VERSION

belong to the same release operation.

---

## Bash Lesson — Variable Scope

Helper functions should declare internal variables with `local`.

Example:

    show_image() {
        local image
        local version
        ...
    }

Without `local`, a helper function can unexpectedly modify variables belonging to its caller.

This caused a real deployment bug during Lab 09 and demonstrated why variable scope matters in shell automation.

---

## Final Lab State

Equipment Monitor:

    Version:       1.1
    Replicas:      3
    Ready:         3/3
    Pod restarts:  0
    Redis:         Ready
    Tailscale:     Healthy

Lab 09 successfully demonstrated upgrade, verification, rollback, recovery, troubleshooting, and health-probe tuning.
