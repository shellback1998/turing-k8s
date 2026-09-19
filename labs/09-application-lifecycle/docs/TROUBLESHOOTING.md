# Lab 09 Troubleshooting

## 1. Upgrade Reported Success But Image Stayed at v1.0

During development of the upgrade command, APP_VERSION changed to 1.1 while the container image remained at 1.0.

Strict release verification detected the mismatch:

    Expected release: 1.1
    Image tag:        1.0
    APP_VERSION:      1.1

The CLI correctly refused to report the release as successful.

### Root Cause

The Bash `show_image()` function used:

    image=...
    version=...

without declaring those variables local.

The calling `upgrade_app()` function also contained a local variable named `image`.

Because Bash uses dynamic scoping for function-local variables, `show_image()` changed the caller's `image` value from the requested v1.1 image back to the currently deployed v1.0 image.

### Fix

Variables inside `show_image()` were explicitly declared:

    local image
    local version

This prevented the helper function from modifying its caller's variables.

---

## 2. Separate Image and Environment Updates

Originally the CLI performed:

    kubectl set image
    kubectl set env

as separate Deployment mutations.

The upgrade was changed to use one strategic Deployment patch so that:

- container image
- APP_VERSION
- release change information

are handled as a single release operation.

---

## 3. Browser Still Displayed v1.0 After Successful Upgrade

Kubernetes verification showed v1.1 was running, but the browser continued displaying the older dashboard.

A hard refresh displayed the correct v1.1 page.

This demonstrated that browser caching can make a successful server-side deployment appear unsuccessful.

Future application versions should send appropriate HTTP cache-control headers for the dynamic dashboard.

---

## 4. Health Probe Failures

The application eventually showed intermittent:

    context deadline exceeded

and:

    connection refused

probe failures.

Application logs showed no Python exceptions or Gunicorn worker crashes.

The manifest did not specify `timeoutSeconds`, meaning Kubernetes used its one-second default.

The probes were tuned to:

    timeoutSeconds: 3
    failureThreshold: 3

After the new pod template rolled out, all three application pods were Ready with zero restarts.

---

## 5. Temporary Verification Image Pull Failure

The temporary curl verification pod briefly failed to resolve Docker Hub while pulling:

    curlimages/curl

Kubernetes retried and successfully pulled the image shortly afterward.

This was a temporary registry/DNS connectivity issue rather than an Equipment Monitor application failure.
