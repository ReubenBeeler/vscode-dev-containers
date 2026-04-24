#!/usr/bin/env bash
{ # prevents execution from breaking due to concurrent modification
	set -e

	echo ┌──────────────────┐
	echo │ System utilities │
	echo └──────────────────┘

	echo 'apt updating and upgrading...'
	sudo apt-get update -y > /dev/null
	# Hold tzdata so apt-get upgrade doesn't try to hard-link over the bind-mounted
	# timezone files from devcontainer feature match-host-time-zone
	sudo apt-mark hold tzdata
	sudo apt-get upgrade -y > /dev/null

	echo 'apt installing basic utilities...'
	sudo apt-get install -y > /dev/null \
		curl git zip unzip xz-utils moreutils

	echo ┌─────┐
	echo │ Act │ # (run GitHub Actions locally)
	echo └─────┘

	curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash -s -- -b /usr/local/bin

	echo ┌──────────┐
	echo │ Lefthook │
	echo └──────────┘

	LEFTHOOK_VERSION=$(curl -fsSL https://api.github.com/repos/evilmartians/lefthook/releases/latest | grep -o '"tag_name": "v[^"]*"' | grep -o '[0-9][^"]*')
	echo "installing lefthook version $LEFTHOOK_VERSION..."
	LEFTHOOK_DEB=$(mktemp --suffix='.deb')
	curl -fsSL -o "$LEFTHOOK_DEB" "https://github.com/evilmartians/lefthook/releases/download/v${LEFTHOOK_VERSION}/lefthook_${LEFTHOOK_VERSION}_amd64.deb"
	sudo apt-get install -y "$LEFTHOOK_DEB" > /dev/null
	rm "$LEFTHOOK_DEB"

	echo ┌─────────────────────┐
	echo │ Android Development │
	echo └─────────────────────┘

	# Do NOT install the 'adb' apt package here. The SDK's platform-tools
	# (installed via sdkmanager below) provides adb. A system adb with a different
	# version will kill and restart the ADB server locally, breaking the connection
	# to the host's server (shared via --network=host).
	echo 'apt installing android toolchain...'
	sudo apt-get install -y > /dev/null \
		android-sdk-platform-tools-common \
		openjdk-17-jdk libpulse0

	# Allow hardware-accelerated emulation via /dev/kvm.
	sudo groupadd -f kvm
	sudo usermod -aG kvm vscode

	# Use the host's bind-mounted Android SDK at ~/.android/SDK
	ANDROID_ENV_BLOCK='
	# Android SDK
	export ANDROID_HOME="$HOME/.android/SDK"
	export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
	'
	eval "$ANDROID_ENV_BLOCK"
	grep -qF 'ANDROID_HOME' ~/.bashrc  || echo -n "$ANDROID_ENV_BLOCK" >> ~/.bashrc
	grep -qF 'ANDROID_HOME' ~/.profile || echo -n "$ANDROID_ENV_BLOCK" >> ~/.profile

	echo ┌───────┐
	echo │ udevd │ # automatic USB device node management
	echo └───────┘

	echo 'apt installing udev...'
	sudo apt-get install -y udev > /dev/null

	echo 'preparing udevd...'

	sudo mkdir -p /dev/bus/usb
	sudo /lib/systemd/systemd-udevd --daemon

	# Override 51-android.rules MODE=0660 with world-accessible permissions.
	echo 'SUBSYSTEM=="usb", MODE="0666"' | sudo tee /etc/udev/rules.d/99-usb-open-access.rules > /dev/null
	sudo udevadm control --reload-rules

	# Coldplug: create nodes for USB devices already present.
	sudo udevadm trigger --subsystem-match=usb --action=add
	sudo udevadm settle --timeout=5

	# Remove stale nodes Docker snapshotted for since-unplugged devices.
	for node in /dev/bus/usb/*/*; do
		bus=$(basename "$(dirname "$node")" | sed 's/^0*//')
		dev=$(basename "$node" | sed 's/^0*//')
		found=false
		for d in /sys/bus/usb/devices/*; do
			[ "$(cat "$d/busnum" 2>/dev/null)" = "$bus" ] && \
			[ "$(cat "$d/devnum" 2>/dev/null)" = "$dev" ] && { found=true; break; }
		done
		$found || sudo rm -f "$node"
	done

	# Ensure udevd stays running across new shell sessions.
	UDEVD_ENV_BLOCK='
# udevd for automatic USB device node management
if ! pgrep -x systemd-udevd >/dev/null 2>&1; then
	sudo /lib/systemd/systemd-udevd --daemon 2>/dev/null
	sudo udevadm trigger --subsystem-match=usb --action=add 2>/dev/null
fi
'
	grep -qF 'systemd-udevd' ~/.bashrc  || echo -n "$UDEVD_ENV_BLOCK" >> ~/.bashrc
	grep -qF 'systemd-udevd' ~/.profile || echo -n "$UDEVD_ENV_BLOCK" >> ~/.profile

	echo ┌───────────────────┐
	echo │ Linux Development │
	echo └───────────────────┘

	echo 'apt installing linux toolchain...'
	sudo apt-get install -y > /dev/null \
		clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-14-dev \
		mesa-utils xvfb

	# Grant access to GPU render nodes so eglinfo (used by flutter doctor) can
	# query driver information. The host DRI devices are visible via --network=host
	# but their owning groups don't map inside the container.
	if [ -d /dev/dri ]; then
		sudo chmod 666 /dev/dri/* 2>/dev/null || true
	fi

	# Start a virtual X server so eglinfo's X11 platform probe doesn't hang
	# (no display server in a headless container). Xvfb also enables running
	# Flutter Linux desktop apps headlessly for testing.
	Xvfb :99 -screen 0 1024x768x24 &>/dev/null &
	export DISPLAY=:99

	# Ensure Xvfb is running and DISPLAY is set in future shells so eglinfo (and Flutter Linux desktop apps) work in this headless container.
	XVFB_ENV_BLOCK='
	# Virtual X server for headless Flutter Linux desktop
	if ! pgrep -x Xvfb >/dev/null 2>&1; then
		Xvfb :99 -screen 0 1024x768x24 &>/dev/null &
	fi
	export DISPLAY=:99
	'
	grep -qF 'Xvfb' ~/.bashrc  || echo -n "$XVFB_ENV_BLOCK" >> ~/.bashrc
	grep -qF 'Xvfb' ~/.profile || echo -n "$XVFB_ENV_BLOCK" >> ~/.profile

	echo ┌────────┐
	echo │ Chrome │
	echo └────────┘

	echo 'installing chrome stable...'
	CHROME_DEB=$(mktemp --suffix='.deb')
	curl -fsSL -o "$CHROME_DEB" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
	sudo apt-get install -y "$CHROME_DEB" > /dev/null
	rm "$CHROME_DEB"

	echo ┌────────────────┐
	echo │ Dart + Flutter │
	echo └────────────────┘

	echo 'installing Dart and Flutter SDKs...'
	FLUTTER_TAR=$(mktemp --suffix='.tar')
	curl -fsSL -o "$FLUTTER_TAR" \
		"https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.41.6-stable.tar.xz"
	tar -xf "$FLUTTER_TAR" -C "$HOME"
	rm "$FLUTTER_TAR"

	# Add Flutter to PATH for all future shells
	FLUTTER_ENV_BLOCK='
	# Flutter
	export PATH="$HOME/flutter/bin:$PATH"
	'
	grep -qxF 'export PATH="$HOME/flutter/bin:$PATH"' ~/.bashrc  || echo -n "$FLUTTER_ENV_BLOCK" >> ~/.bashrc
	grep -qxF 'export PATH="$HOME/flutter/bin:$PATH"' ~/.profile || echo -n "$FLUTTER_ENV_BLOCK" >> ~/.profile
	eval "$FLUTTER_ENV_BLOCK"

	dart --disable-analytics >/dev/null
	flutter --disable-analytics >/dev/null
	flutter upgrade

	# Wire Flutter to the SDK we just installed
	flutter config --android-sdk "$ANDROID_HOME" --enable-linux-desktop --no-analytics

	# Accept Android licenses via Flutter and run a sanity check
	flutter doctor --android-licenses --no-version-check < /dev/null || true
	flutter doctor --no-version-check || true

	DART_ENV_BLOCK='
	# Dart/Flutter packages
	export PATH="$PATH:$HOME/.pub-cache/bin"
	'
	grep -qxF 'export PATH="$PATH:$HOME/.pub-cache/bin"' ~/.bashrc  || echo -n "$DART_ENV_BLOCK" >> ~/.bashrc
	grep -qxF 'export PATH="$PATH:$HOME/.pub-cache/bin"' ~/.profile || echo -n "$DART_ENV_BLOCK" >> ~/.profile
	eval "$DART_ENV_BLOCK"

	echo ┌──────────┐
	echo │ Firebase │
	echo └──────────┘

	curl -sL https://firebase.tools | bash
	dart pub global activate flutterfire_cli

	echo ┌──────┐
	echo │ Deno │
	echo └──────┘

	DENO_ENV_BLOCK='
	# deno
	export DENO_INSTALL="$HOME/.deno"
	export PATH="$DENO_INSTALL/bin:$PATH"
	'
	grep -qF 'DENO_INSTALL' ~/.bashrc  || echo -n "$DENO_ENV_BLOCK" >> ~/.bashrc
	grep -qF 'DENO_INSTALL' ~/.profile || echo -n "$DENO_ENV_BLOCK" >> ~/.profile
	eval "$DENO_ENV_BLOCK"

	curl -fsSL https://deno.land/install.sh | sh -s -- -y

	COMPLETIONS_DIR="$HOME/.local/share/bash-completion/completions"
	mkdir -p "$COMPLETIONS_DIR"
	deno completions bash > "$COMPLETIONS_DIR/deno"

	echo ┌─────┐
	echo │ Bun │
	echo └─────┘

	curl -fsSL https://bun.sh/install | bash
	export BUN_INSTALL="$HOME/.bun"
	export PATH="$BUN_INSTALL/bin:$PATH"

	echo ┌─────┐
	echo │ fnm │
	echo └─────┘

	curl -fsSL https://fnm.vercel.app/install | bash

	FNM_PATH="/home/vscode/.local/share/fnm"
	if [ -d "$FNM_PATH" ]; then
		export PATH="$FNM_PATH:$PATH"
		eval "$(fnm env --shell bash)"
	fi

	echo ┌─────────────┐
	echo │ Claude Code │
	echo └─────────────┘

	## Config

	# sanity
	mkdir -p ~/.claude

	# bind mounted ~/.claude/.credentials.json so need to update ~/.claude permissions
	sudo chown $USER ~/.claude
	sudo chgrp $USER ~/.claude

	# Copy statusline.sh staged by hostConfig.sh into the container
	STATUSLINE_PATH='.devcontainer/ubuntu-flutter/statusline.sh'
	if [ -f "$STATUSLINE_PATH" ]; then
		mv "$STATUSLINE_PATH" ~/.claude/statusline.sh
	fi

	# Configure statusline in user-level settings
	if [ -f ~/.claude/statusline.sh ]; then
		SETTINGS_PATH=~/.claude/settings.json
		SETTINGS_JSON=\
'{
	"env": {
		"DISABLE_AUTOUPDATER": "1"
	},
	"statusLine": {
		"type": "command",
		"command": "bash ~/.claude/statusline.sh"
	},
	"skipDangerousModePermissionPrompt": true
}'
		if [ -f "$SETTINGS_PATH" ]; then
			# Merge statusLine into existing settings
			jq ". + $SETTINGS_JSON" "$SETTINGS_PATH" | sponge "$SETTINGS_PATH"
		else
			echo "$SETTINGS_JSON" > "$SETTINGS_PATH"
		fi
	fi

	# jq '. + {"hasCompletedOnboarding": true}' ~/.claude.json | sponge ~/.claude.json
	if [ ! -f ~/.claude.json ]; then
		cat > ~/.claude.json <<EOF
{
	"hasCompletedOnboarding": true,
	"projects": {
		"$PWD": {
			"hasTrustDialogAccepted": true
		}
	}
}
EOF
	fi

	echo 'claude --permission-mode bypassPermissions' >> ~/.bash_history

	## Install Claude Code

	curl -fsSL https://claude.ai/install.sh | bash -s 2.1.98  # old version should fix caching issues
	# see {"env": {"DISABLE_AUTOUPDATER": "1"}} in settings json for version pin

	## Claude Code Extensions

	# mobile dev MCP server (https://github.com/AlexGladkov/claude-in-mobile)
	claude mcp add --scope user --transport stdio mobile -- bunx -y claude-in-mobile
	# dart MCP server (https://docs.flutter.dev/ai/mcp-server)
	claude mcp add --scope user --transport stdio dart -- dart mcp-server


	exit 0
}