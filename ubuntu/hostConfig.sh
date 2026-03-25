#!/usr/bin/env bash
# hostConfig.sh — runs on your host before every build of this devcontainer
set -e

# Copy host files into the workspace so postCreate can place them inside the container.
STATUSLINE="$HOME/.claude/statusline.sh"
if [ -f "$STATUSLINE" ]; then
  cp "$STATUSLINE" .devcontainer/ubuntu/statusline.sh
fi
