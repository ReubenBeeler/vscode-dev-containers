#!/usr/bin/env bash
# hostConfig.sh — runs on your host before every build of this devcontainer
#
# The devcontainer uses --network=host, so it shares the host's network namespace.
# The host's ADB server at localhost:5037 is directly reachable from the container.
# This script installs udev rules, installs adb, and starts the host ADB server.

set -e

if ADB_PATH=$(which adb 2>/dev/null); then
	echo "✅ adb installed: $ADB_PATH"
else
	echo "❌ adb not installed! Attempting install..."
	sudo apt-get update -y
	sudo apt-get install -y android-tools-adb android-sdk-platform-tools-common
	
	# android-sdk-platform-tools-common ships /etc/udev/rules.d/51-android.rules,
	# covering nearly every Android vendor ID.
	echo "==> Reloading udev rules..."
	sudo udevadm control --reload-rules
	sudo udevadm trigger
fi

echo "==> Adding $USER to the 'plugdev' group (needed for non-root USB access)..."
if id -nG "$USER" | grep -qw 'plugdev'; then
	echo "✅ $USER belongs to group 'plugdev'"
else
	echo "❌ $USER does not belong to group 'plugdev'! Attempting to add user..."
    sudo usermod -aG plugdev "$USER"
fi

# I shouldn't need to kill it unless modifying plugdev right?...
echo "==> Starting host ADB server..."
adb kill-server 2>/dev/null || true
adb start-server

# ┌─────────────────────────────┐
# │ Stage host files for copy   │
# └─────────────────────────────┘

STATUSLINE="$HOME/.claude/statusline.sh"
if [ -f "$STATUSLINE" ]; then
  cp "$STATUSLINE" .devcontainer/ubuntu-flutter/statusline.sh
fi
