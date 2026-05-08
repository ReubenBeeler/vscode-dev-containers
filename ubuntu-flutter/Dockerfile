FROM mcr.microsoft.com/devcontainers/base:noble

# Run post-build setup as vscode — installs SDKs and tools into the image.
# postCreate.sh and postStart.sh are bind-mounted at runtime via devcontainer.json
# into /opt/this-container/ (the entire Dockerfile directory, read-only).
# The match-host-time-zone feature is absent here; the apt-mark hold tzdata line
# in postBuild.sh is a no-op without it and causes no harm.
# Pass TZ at runtime via -e TZ=<zone> if timezone sync is needed.
USER vscode
RUN bash <<'EOPOSTCREATE'
#!/usr/bin/env bash
{ # prevents execution from breaking from concurrent modification
	set -euo pipefail

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
	# usermod -aG only takes effect in new login sessions, so also open the
	# device node directly so the current container session can use KVM
	# immediately after postCreate without a rebuild.
	sudo groupadd -f kvm
	sudo usermod -aG kvm vscode
	sudo chmod 666 /dev/kvm || true  # no-op if /dev/kvm absent (CI, non-KVM host)

	# Install Android SDK locally
	ANDROID_HOME="$HOME/.android/SDK"
	mkdir -p "$ANDROID_HOME/cmdline-tools"

	CMDLINE_TOOLS_ZIP=$(mktemp --suffix='.zip')
	curl -fsSL -o "$CMDLINE_TOOLS_ZIP" \
		"https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
	unzip -q "$CMDLINE_TOOLS_ZIP" -d "$ANDROID_HOME/cmdline-tools"
	mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
	rm "$CMDLINE_TOOLS_ZIP"

	export ANDROID_HOME
	export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

	yes | sdkmanager --licenses > /dev/null 2>&1 || true
	sdkmanager \
		"platform-tools" \
		"build-tools;34.0.0" \
		"platforms;android-36" \
		"emulator" \
		"system-images;android-36;google_apis;x86_64"

	# Create Pixel API 36 AVD
	echo "no" | avdmanager create avd \
		-n Pixel_API_36 \
		-k "system-images;android-36;google_apis;x86_64"
	echo

	ANDROID_ENV_BLOCK='
	# Android SDK
	export ANDROID_HOME="$HOME/.android/SDK"
	export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
	'
	grep -qF 'ANDROID_HOME' ~/.bashrc  || echo -n "$ANDROID_ENV_BLOCK" >> ~/.bashrc
	grep -qF 'ANDROID_HOME' ~/.profile || echo -n "$ANDROID_ENV_BLOCK" >> ~/.profile

	echo ┌───────┐
	echo │ udevd │ # automatic USB device node management
	echo └───────┘

	echo 'apt installing udev...'
	sudo apt-get install -y udev > /dev/null

	echo 'preparing udevd...'

	# Override 51-android.rules MODE=0660 with world-accessible permissions.
	echo 'SUBSYSTEM=="usb", MODE="0666"' | sudo tee /etc/udev/rules.d/99-usb-open-access.rules > /dev/null

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
		libsqlite3-dev mesa-utils xvfb \
		openbox at-spi2-core dbus-x11 xdotool
	
	export DISPLAY=:99

	# Ensure all headless desktop services are running in future shells.
	LINUX_DESKTOP_ENV_BLOCK='
	# Headless desktop environment for Flutter Linux desktop testing
	if ! pgrep -x Xvfb >/dev/null 2>&1; then
		Xvfb :99 -screen 0 1024x768x24 &>/dev/null &
	fi
	export DISPLAY=:99

	if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
		eval $(dbus-launch --sh-syntax)
		export DBUS_SESSION_BUS_ADDRESS
	fi

	if ! pgrep -x at-spi2-registryd >/dev/null 2>&1; then
		/usr/libexec/at-spi2-registryd &>/dev/null &
	fi

	if ! pgrep -x openbox >/dev/null 2>&1; then
		openbox &>/dev/null &
	fi
	'
	grep -qF 'Xvfb' ~/.bashrc  || echo -n "$LINUX_DESKTOP_ENV_BLOCK" >> ~/.bashrc
	grep -qF 'Xvfb' ~/.profile || echo -n "$LINUX_DESKTOP_ENV_BLOCK" >> ~/.profile

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
	# Wire Flutter to the SDK we just installed
	flutter config --android-sdk "$ANDROID_HOME" --enable-linux-desktop --no-analytics --no-version-check

	# Accept Android licenses via Flutter and run a sanity check
	flutter doctor --android-licenses --no-version-check < /dev/null || true

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

	echo ┌────────┐
	echo │ Python │
	echo └────────┘

	# uv
	curl -LsSf https://astral.sh/uv/install.sh | sh

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

	echo 'claude --permission-mode bypassPermissions' >> ~/.bash_history

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

	## Install Claude Code

	curl -fsSL https://claude.ai/install.sh | bash -s 2.1.98  # old version should fix caching issues
	# see {"env": {"DISABLE_AUTOUPDATER": "1"}} in settings json for version pin
	export PATH="$HOME/.local/bin:$PATH"

	## Claude Code Extensions

	# marionette MCP server (https://github.com/leancodepl/marionette_mcp)
	dart pub global activate marionette_mcp
	claude mcp add --scope user --transport stdio marionette -- dart pub global run marionette_mcp
	# Chrome DevTools MCP server
	claude mcp add --scope user chrome-devtools -- bunx chrome-devtools-mcp@latest --no-usage-statistics
	# dart MCP server (https://docs.flutter.dev/ai/mcp-server)
	claude mcp add --scope user dart -- dart mcp-server


	# Wrap flutter to fix root-owned ephemeral files before clean
	# (the dart MCP server can create root-owned .plugin_symlinks)
	cat >> ~/.bashrc << 'FLUTTER_WRAPPER'

flutter() {
    if [ "$1" = "clean" ]; then
        local ephemeral
        for ephemeral in $(find . -path '*/flutter/ephemeral' -type d 2>/dev/null); do
            if find "$ephemeral" -user root -print -quit 2>/dev/null | grep -q .; then
                sudo chown -R "$USER:$USER" "$ephemeral"
            fi
        done
    fi
    command flutter "$@"
}
FLUTTER_WRAPPER

	echo ┌─\────────────────────────┐
	echo │ ✅  Completed PostCreate │
	echo └─\────────────────────────┘

	exit 0
}
EOPOSTCREATE
USER root
