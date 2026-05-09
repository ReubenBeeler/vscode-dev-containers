#!/usr/bin/env bash
# postStart.sh — starts runtime services on every container start.
# All starts are idempotent (pgrep/command-v guarded), so this script is
# safe to call multiple times (e.g. inline from postCreate.sh).
{ # prevents execution from breaking from concurrent modification
	set -euo pipefail
	
	echo ┌─────┐
	echo │ DNS │
	echo └─────┘

	echo "==> Configuring fallback DNS servers and resolver timeouts..."
	if ! grep -q 'single-request-reopen' /etc/resolv.conf 2>/dev/null; then
		original_ns=$(grep -m1 '^nameserver' /etc/resolv.conf || echo "nameserver 192.168.85.1")
		sudo tee /etc/resolv.conf >/dev/null <<-EOF
		$original_ns
		nameserver 8.8.8.8
		nameserver 1.1.1.1
		options single-request-reopen timeout:1 attempts:5
		EOF
	fi

	echo ┌───────┐
	echo │ udevd │
	echo └───────┘

	echo "==> Creating /dev/bus/usb..."
	sudo mkdir -p /dev/bus/usb

	echo "==> Starting systemd-udevd daemon..."
	if ! pgrep -x systemd-udevd >/dev/null 2>&1; then
		sudo /lib/systemd/systemd-udevd --daemon
	fi

	echo "==> Reloading udev rules and triggering USB scan..."
	sudo udevadm control --reload-rules
	sudo udevadm trigger --subsystem-match=usb --action=add
	sudo udevadm settle --timeout=5

	echo "==> Removing stale USB device nodes..."
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

	echo ┌─────┐
	echo │ ADB │
	echo └─────┘

	echo "==> Setting ANDROID_HOME and PATH..."
	export ANDROID_HOME="$HOME/.android/SDK"
	export PATH="$ANDROID_HOME/platform-tools:$PATH"

	echo "==> Verifying ADB connectivity to host server..."
	adb devices

	echo ┌──────────────────┐
	echo │ Headless desktop │
	echo └──────────────────┘

	echo "==> Granting access to GPU render nodes..."
	if [ -d /dev/dri ]; then
		sudo chmod 666 /dev/dri/* 2>/dev/null || true
	fi

	echo "==> Starting Xvfb virtual X server on :99..."
	if command -v Xvfb >/dev/null 2>&1 && ! pgrep -x Xvfb >/dev/null 2>&1; then
		# Clean stale X server state from previous container lifecycle.
		# Lock files and filesystem sockets can be simply removed.
		# Abstract sockets (@/tmp/.X11-unix/X99) are kernel-managed and
		# cannot be removed from userspace, so -nolisten local avoids them.
		rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
		Xvfb :99 -screen 0 1024x768x24 -nolisten local &>/dev/null &
		# Wait for Xvfb to initialize before clients try to connect.
		sleep 1
	fi
	export DISPLAY=:99

	echo "==> Starting D-Bus session bus..."
	if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] || \
			! dbus-send --session --dest=org.freedesktop.DBus --print-reply \
				/org/freedesktop/DBus org.freedesktop.DBus.Peer.Ping &>/dev/null; then
		eval "$(dbus-launch --sh-syntax)"
		export DBUS_SESSION_BUS_ADDRESS
	fi

	echo "==> Unlocking gnome-keyring with empty password..."
	if command -v gnome-keyring-daemon >/dev/null 2>&1; then
		pkill -9 -f gnome-keyring-daemon || true
		echo "" | gnome-keyring-daemon --unlock > /dev/null
	fi

	echo "==> Starting AT-SPI2 accessibility bus launcher..."
	if [ -x /usr/libexec/at-spi-bus-launcher ] && \
			! pgrep -x at-spi-bus-lau >/dev/null 2>&1; then
		DISPLAY=:99 /usr/libexec/at-spi-bus-launcher --launch-immediately &>/dev/null &
		sleep 1
	fi
	echo "==> Starting AT-SPI2 registry daemon..."
	if [ -x /usr/libexec/at-spi2-registryd ] && \
			! pgrep -x at-spi2-registr >/dev/null 2>&1; then
		DISPLAY=:99 /usr/libexec/at-spi2-registryd &>/dev/null &
	fi

	echo "==> Starting Openbox window manager..."
	if command -v openbox >/dev/null 2>&1 && ! pgrep -x openbox >/dev/null 2>&1; then
		DISPLAY=:99 openbox --replace &>/dev/null &
	fi

	echo ┌─────────────────┐
	echo │ Sanity check... │
	echo └─────────────────┘
	
	SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
	bash "$SCRIPT_DIR/test-postStart.sh"

	echo ┌─\───────────────────────┐
	echo │ ✅  Completed PostStart │
	echo └─\───────────────────────┘
	
}
