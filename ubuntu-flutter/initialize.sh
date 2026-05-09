#!/usr/bin/env bash
# initialize.sh — runs on the HOST before the container is created.
# 1. Ensures the Docker image is available (local registry).
# 2. Starts the ADB server on the host so USB devices are tracked
#    before the container (which uses --network=host) comes up.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Docker image ──────────────────────────────────────────────────────────────
bash "${SCRIPT_DIR}/ensure-image.sh"

# ── ADB server ────────────────────────────────────────────────────────────────
# The container shares the host network (--network=host), so the host's ADB
# server on localhost:5037 is reachable from inside the container.  Starting it
# here guarantees a fresh USB scan before the container's postStart.sh runs.
if command -v adb >/dev/null 2>&1; then
	echo "==> Starting ADB server on host..."
	adb start-server
else
	echo "WARN: adb not found on host — USB device passthrough may not work." >&2
fi
