# Release Management

## View Current Release

    equipment-monitor image

Displays:

- Container image
- Image tag
- APP_VERSION

## Upgrade

Example:

    equipment-monitor upgrade 1.1

The CLI validates that the requested image tag exists in the private registry before changing Kubernetes.

The image and APP_VERSION are changed together as one Deployment pod-template update.

After rollout, the CLI verifies:

    Expected release: 1.1
    Image tag:        1.1
    APP_VERSION:      1.1

It then performs an end-to-end request through the Kubernetes Service.

## History

    equipment-monitor history

Kubernetes Deployment revisions represent changes to the Deployment pod template.

A revision number should not automatically be assumed to represent a good release.

## Rollback

Inspect history first:

    equipment-monitor history

Then explicitly select the desired revision:

    equipment-monitor rollback REVISION

The CLI displays the selected revision and requires confirmation before performing the rollback.

## Important Principle

Deployment success and release success are not the same thing.

A Kubernetes rollout may technically complete even when the wrong application image was deployed.

Release verification must independently confirm the expected state.
