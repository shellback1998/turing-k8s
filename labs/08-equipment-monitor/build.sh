#!/usr/bin/env bash
set -euo pipefail

BUILD_NODE="piadmin@192.168.8.191"
BUILD_DIR="/tmp/equipment-monitor-build"
SOURCE_DIR="$HOME/k8s-lab/labs/08-equipment-monitor/app"

REGISTRY="192.168.8.191:5000"
IMAGE="equipment-monitor"
TAG="${1:-1.0}"

FULL_IMAGE="${REGISTRY}/${IMAGE}:${TAG}"

echo "========================================"
echo " Equipment Monitor Build"
echo "========================================"
echo
echo "Image:      $FULL_IMAGE"
echo "Build node: $BUILD_NODE"
echo

echo "[1/5] Checking build node..."
ssh "$BUILD_NODE" 'docker --version >/dev/null && test "$(uname -m)" = "aarch64"'
echo "✓ ARM64 Docker build node ready"

echo
echo "[2/5] Preparing remote build directory..."
ssh "$BUILD_NODE" "rm -rf '$BUILD_DIR' && mkdir -p '$BUILD_DIR'"

echo
echo "[3/5] Copying application source..."
scp -q "$SOURCE_DIR/app.py" \
       "$SOURCE_DIR/requirements.txt" \
       "$SOURCE_DIR/Dockerfile" \
       "$BUILD_NODE:$BUILD_DIR/"
echo "✓ Source copied"

echo
echo "[4/5] Building ARM64 image..."
ssh "$BUILD_NODE" \
    "cd '$BUILD_DIR' && docker build -t '$FULL_IMAGE' ."

echo
echo "[5/5] Pushing image to registry..."
ssh "$BUILD_NODE" \
    "docker push '$FULL_IMAGE'"

echo
echo "Cleaning temporary build files..."
ssh "$BUILD_NODE" "rm -rf '$BUILD_DIR'"

echo
echo "========================================"
echo " BUILD COMPLETE"
echo "========================================"
echo
echo "Image:"
echo "  $FULL_IMAGE"
