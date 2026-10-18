#!/usr/bin/env bash
# Build academy-lab-linux natively on turing-node01 (arm64 Docker, same pattern as
# labs/08-equipment-monitor/build.sh) and push it to the local registry on that node.
#   academy-labs/build-image.sh <path-to-scottacademy>/infra/labs/linux-image <tag>
set -euo pipefail

SOURCE_DIR="${1:?path to scottacademy infra/labs/linux-image}"
TAG="${2:?image tag, for example 2026.10.18-1}"
BUILD_NODE="piadmin@192.168.8.191"
BUILD_DIR="/tmp/academy-lab-linux-build"
REGISTRY="192.168.8.191:5000"
FULL_IMAGE="${REGISTRY}/academy-lab-linux:${TAG}"

[[ -f "$SOURCE_DIR/Dockerfile" ]] || { echo "No Dockerfile in $SOURCE_DIR" >&2; exit 1; }
[[ "$TAG" =~ ^[A-Za-z0-9._-]+$ && "$TAG" != latest ]] || { echo "Use an explicit, non-latest tag" >&2; exit 1; }

echo "[1/5] Checking build node (arm64 Docker, 1.5 GB free)"
ssh "$BUILD_NODE" 'docker --version >/dev/null && test "$(uname -m)" = aarch64 &&
  test "$(df --output=avail -BM /var/lib/docker 2>/dev/null | tail -1 | tr -dc 0-9)" -ge 1500'

echo "[2/5] Refusing to overwrite an existing tag"
if ssh "$BUILD_NODE" "curl -fsS -o /dev/null http://$REGISTRY/v2/academy-lab-linux/manifests/$TAG -H 'Accept: application/vnd.docker.distribution.manifest.v2+json'"; then
  echo "$FULL_IMAGE already exists; pick a new tag" >&2; exit 1
fi

echo "[3/5] Copying build context"
ssh "$BUILD_NODE" "rm -rf '$BUILD_DIR' && mkdir -p '$BUILD_DIR'"
tar -C "$SOURCE_DIR" -czf - Dockerfile .dockerignore practice smoke-test.sh | ssh "$BUILD_NODE" "tar -C '$BUILD_DIR' -xzf -"

echo "[4/5] Building and smoke-testing"
ssh "$BUILD_NODE" "cd '$BUILD_DIR' && DOCKER_BUILDKIT=1 docker build --pull -t '$FULL_IMAGE' . && bash smoke-test.sh '$FULL_IMAGE'"

echo "[5/5] Pushing"
ssh "$BUILD_NODE" "docker push '$FULL_IMAGE' && rm -rf '$BUILD_DIR'"

echo "Built and pushed $FULL_IMAGE"
echo "Next: ansible-playbook playbooks/academy-labs.yml --tags prepull -e academy_lab_image_tag=$TAG"
