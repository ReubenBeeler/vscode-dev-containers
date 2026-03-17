#!/usr/bin/env bash
set -e

# ┌─────┐
# │ Act │ (run GitHub Actions locally)
# └─────┘

curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
sudo mv bin/act /usr/local/bin
rmdir bin

# ┌─────────┐
# │ Android │
# └─────────┘

sudo apt-get update -y && sudo apt-get upgrade -y

# Core utilities + udev rules + Java (required by Android build tools)
# NOTE: Do NOT install the 'adb' apt package here. The SDK's platform-tools
# (installed via sdkmanager below) provides adb. A system adb with a different
# version will kill and restart the ADB server locally, breaking the connection
# to the host's server (shared via --network=host).
sudo apt-get install -y \
  curl git unzip xz-utils zip \
  android-sdk-platform-tools-common \
  openjdk-17-jdk

# Grant the container user access to KVM for hardware-accelerated emulation.
# /dev/kvm is passed in via --device=/dev/kvm but its owning group (numeric)
# doesn't map to a named group inside the container. Using gpasswd alone is
# insufficient because group membership only takes effect in new login sessions,
# not the current shell running postCreate. Set world read/write so the
# emulator can use KVM immediately without requiring a re-login.
sudo chmod 666 /dev/kvm

# Android SDK (cmdline-tools → sdkmanager → platform + build-tools)
ANDROID_SDK_ROOT="$HOME/android-sdk"
CMDLINE_TOOLS_ZIP="cmdline-tools.zip"
# commandlinetools-linux 11076708 = SDK tools 2024.* (latest stable as of Flutter 3.x)
curl -fsSL -o "$CMDLINE_TOOLS_ZIP" \
  "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
unzip -q "$CMDLINE_TOOLS_ZIP" -d "$ANDROID_SDK_ROOT/cmdline-tools"
# sdkmanager requires the directory to be named "latest"
mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
rm "$CMDLINE_TOOLS_ZIP"

export ANDROID_SDK_ROOT
export PATH="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

# Accept all SDK licenses non-interactively, then install required components
yes | sdkmanager --licenses 2>/dev/null >/dev/null || true
sdkmanager \
  "platform-tools" \
  "build-tools;36.0.0" \
  "build-tools;28.0.3" \
  "platforms;android-36" \
  "emulator" \
  "system-images;android-36;google_apis;x86_64"

# Create a default AVD for the emulator
avdmanager list avd -c | grep -qx "Pixel_API_36" || \
  echo "no" | avdmanager create avd -n "Pixel_API_36" -k "system-images;android-36;google_apis;x86_64" --device "pixel_6"

# Persist Android SDK env for all future shells
ANDROID_ENV_BLOCK='# Android SDK
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"'
grep -qF 'ANDROID_SDK_ROOT' ~/.bashrc  || printf '\n%s\n' "$ANDROID_ENV_BLOCK" >> ~/.bashrc
grep -qF 'ANDROID_SDK_ROOT' ~/.profile || printf '\n%s\n' "$ANDROID_ENV_BLOCK" >> ~/.profile

# ┌─────────┐
# │ Flutter │
# └─────────┘

# Flutter SDK
FLUTTER_TAR='flutter.tar.xz'
curl -fsSL -o "$FLUTTER_TAR" \
  "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.41.4-stable.tar.xz"
tar -xf "$FLUTTER_TAR" -C "$HOME"
rm "$FLUTTER_TAR"

# Add Flutter to PATH for all future shells
FLUTTER_PATH_LINE='export PATH="$HOME/flutter/bin:$PATH"'
grep -qxF "$FLUTTER_PATH_LINE" ~/.bashrc  || echo "$FLUTTER_PATH_LINE" >> ~/.bashrc
grep -qxF "$FLUTTER_PATH_LINE" ~/.profile || echo "$FLUTTER_PATH_LINE" >> ~/.profile

export PATH="$HOME/flutter/bin:$PATH"

# Wire Flutter to the SDK we just installed
flutter config --android-sdk "$ANDROID_SDK_ROOT" --no-analytics

# Accept Android licenses via Flutter and run a sanity check
flutter doctor --android-licenses --no-version-check < /dev/null || true
flutter doctor --no-version-check || true

# ┌─────┐
# │ Bun │
# └─────┘

curl -fsSL https://bun.sh/install | bash	# Auto-adds bun to PATH in ~/.bashrc
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ┌──────┐
# │ Node │ because ruflo hooks use node (even though we install ruflo with bun)
# └──────┘

# ruflo recommends fnm
curl -fsSL https://fnm.vercel.app/install | bash	# Auto-adds bun to PATH in ~/.bashrc

FNM_PATH="/home/vscode/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell bash)"
fi

fnm install 20

# ┌─────────────┐
# │ Claude Code │
# └─────────────┘

## Config

mkdir -p ~/.claude
cp ~/claude-credentials.json ~/.claude/.credentials.json

# sudo apt install -y moreutils
# jq '. + {"hasCompletedOnboarding": true}' ~/.claude.json | sponge ~/.claude.json

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

curl -fsSL https://claude.ai/install.sh | bash

## Claude Code Extensions

# ruflo – agent orchestration
bunx ruflo init < <(echo No) || true # don't overwrite config files if they already exist
bunx ruflo daemon start
bunx ruflo memory configure --backend hybrid
bunx ruflo memory init || true		 # it might fail if one already exists, which is fine
claude mcp add claude-flow bunx @claude-flow/cli@v3alpha mcp start
bun install -D typescript
bun install agentic-flow@latest
bunx ruflo doctor

# mobile dev MCP server (https://github.com/AlexGladkov/claude-in-mobile)
claude mcp add --scope user --transport stdio mobile -- bunx -y claude-in-mobile
