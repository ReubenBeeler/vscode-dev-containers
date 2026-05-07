#!/usr/bin/env bash
set -euo pipefail

# Configurable via environment variables
REGISTRY="${REGISTRY:-localhost:5001}"
IMAGE_NAME="${IMAGE_NAME:-ubuntu-flutter}"
TAG="${TAG:-latest}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FULL_TAG="${REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "Building ${FULL_TAG}..."
docker build --tag "${FULL_TAG}" "${SCRIPT_DIR}"

echo "Pushing to ${REGISTRY}..."
docker push "${FULL_TAG}"

echo "Done: ${FULL_TAG}"
