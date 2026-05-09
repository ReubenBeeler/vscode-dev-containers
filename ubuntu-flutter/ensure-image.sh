#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="${REGISTRY:-localhost:5001}"
IMAGE_NAME="${IMAGE_NAME:-ubuntu-flutter}"
TAG="${TAG:-latest}"
FULL_TAG="${REGISTRY}/${IMAGE_NAME}:${TAG}"
REGISTRY_NAME="local-registry"

# 1. Verify Docker is available
if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker is not running or not installed." >&2
    exit 1
fi

# 2. Ensure the local registry container is running
echo "==> Ensuring local registry at ${REGISTRY}..."
bash "${SCRIPT_DIR}/setup-local-registry.sh" add "${REGISTRY_NAME}"

# 3. Wait for registry readiness
echo "==> Waiting for registry..."
for i in $(seq 1 10); do
    if curl -fsSL "http://${REGISTRY}/v2/" >/dev/null 2>&1; then
        break
    fi
    if [ "$i" -eq 10 ]; then
        echo "ERROR: Registry at ${REGISTRY} is not responding after 10 seconds." >&2
        echo "Check: docker logs ${REGISTRY_NAME}" >&2
        exit 1
    fi
    sleep 1
done

# 4. Check if the image already exists in the registry
echo "==> Checking for ${FULL_TAG}..."
HTTP_CODE=$(curl -so /dev/null -w '%{http_code}' \
    "http://${REGISTRY}/v2/${IMAGE_NAME}/manifests/${TAG}" \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json")
if [ "$HTTP_CODE" = "200" ]; then
    echo "==> Image found. Ready."
    exit 0
fi
echo "==> Image not found (HTTP ${HTTP_CODE})."

# 5. Image not found — build and push
echo ""
echo "============================================================"
echo "  First-time setup: building the devcontainer image."
echo "  This downloads Flutter SDK, Android SDK, Chrome, etc."
echo "  Expected time: 15-30 minutes. Subsequent opens are fast."
echo "============================================================"
echo ""
bash "${SCRIPT_DIR}/rebuild-and-push.sh"
