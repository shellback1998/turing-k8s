# Lab 09 — Kubernetes Application Lifecycle

## Objective

Learn how Kubernetes manages an application through its release lifecycle:

- Container image versioning
- Rolling upgrades
- Release verification
- Rollout history
- Revision-aware rollback
- Recovery from a rollback
- Kubernetes health probes
- Declarative configuration synchronization
- Troubleshooting failed deployments

This lab evolves the Equipment Monitor application created in Lab 08.

---

## Starting State

Equipment Monitor v1.0:

- 3 application replicas
- Flask application served by Gunicorn
- Redis shared state
- Kubernetes ClusterIP Service
- Tailscale LoadBalancer
- ARM64 worker-node placement
- Health and readiness probes

Container image:

    192.168.8.191:5000/equipment-monitor:1.0

---

## Release 1.1

Version 1.1 added application version visibility and an improved dashboard.

The application now exposes its version through `/health`.

Example:

    {
      "application": "Equipment Monitor",
      "pod": "equipment-monitor-...",
      "redis": "ok",
      "status": "ok",
      "version": "1.1"
    }

The dashboard also displays:

- Application Version
- Serving Pod
- Redis Visit Count
- Equipment status indicators
- Automatic page refresh

Container image:

    192.168.8.191:5000/equipment-monitor:1.1

---

## Rolling Upgrade

The management CLI gained:

    equipment-monitor image
    equipment-monitor upgrade TAG
    equipment-monitor history
    equipment-monitor rollback REVISION

An upgrade performs:

1. Validate the requested image tag.
2. Confirm the image exists in the private registry.
3. Display the current release.
4. Update image and APP_VERSION together.
5. Wait for the Kubernetes rollout.
6. Verify the deployed image tag.
7. Verify APP_VERSION.
8. Perform an end-to-end application health request.

A release is not considered successful unless verification passes.

---

## Rollback Exercise

The application was successfully rolled back from v1.1 to the genuine v1.0 revision.

Instead of automatically selecting the previous revision, the CLI requires an explicit revision:

    equipment-monitor rollback REVISION

This matters because a previous revision is not necessarily a known-good release.

After rollback, Kubernetes restored the v1.0 ReplicaSet while the Service remained available.

The application was then successfully upgraded back to v1.1.

---

## Declarative Source of Truth

After the successful v1.1 release, the Kubernetes manifest was synchronized with the live deployment:

    image: 192.168.8.191:5000/equipment-monitor:1.1

and:

    APP_VERSION: "1.1"

This prevents a future `kubectl apply` or `equipment-monitor deploy` from unintentionally restoring v1.0.

---

## Health Probe Tuning

During final validation, application pods experienced intermittent probe timeouts.

The Kubernetes default HTTP probe timeout is one second when `timeoutSeconds` is not specified.

The probes were updated to:

    timeoutSeconds: 3
    failureThreshold: 3

Final state:

- Application replicas: 3/3 Ready
- Application pod restarts: 0
- Redis: Ready
- Kubernetes Service: Present
- Tailscale: Healthy
- Application version: 1.1

---

## Final Result

Lab 09 demonstrated the complete application lifecycle:

    v1.0
      |
      v
    Upgrade
      |
      v
    v1.1
      |
      v
    Rollback
      |
      v
    v1.0
      |
      v
    Upgrade
      |
      v
    v1.1

The Equipment Monitor finished the lab healthy with three application replicas.
