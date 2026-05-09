#!/usr/bin/env bash
# postStart.sh — starts runtime services on every container start.
# All starts are idempotent (pgrep/command-v guarded), so this script is
# safe to call multiple times (e.g. inline from postCreate.sh).
{ # prevents execution from breaking from concurrent modification
	set -euo pipefail
	
	echo ┌─────┐
	echo │ DNS │
	echo └─────┘

	# Docker generates /etc/resolv.conf with only the host's DNS server and no
	# options.  This makes DNS fragile — a single dropped UDP packet on the
	# Docker bridge/NAT path causes a 5-second hang, and 3 drops = 15 s failure.
	# Fix: add fallback public DNS servers and tune resolver timeouts.
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

	sudo mkdir -p /dev/bus/usb

	if ! pgrep -x systemd-udevd >/dev/null 2>&1; then
		sudo /lib/systemd/systemd-udevd --daemon
	fi

	sudo udevadm control --reload-rules
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

	echo ┌─────┐
	echo │ ADB │
	echo └─────┘

	export ANDROID_HOME="$HOME/.android/SDK"
	export PATH="$ANDROID_HOME/platform-tools:$PATH"

	# The host's ADB server is started by initialize.sh (runs on the host
	# before the container).  With --network=host, the container reaches it
	# on localhost:5037.  Just verify connectivity here.
	adb devices

	echo ┌──────────────────┐
	echo │ Headless desktop │
	echo └──────────────────┘

	# Grant access to GPU render nodes so eglinfo can query driver information.
	# The host DRI devices are visible via --network=host but their owning
	# groups don't map inside the container.
	if [ -d /dev/dri ]; then
		sudo chmod 666 /dev/dri/* 2>/dev/null || true
	fi

	# Start a virtual X server so eglinfo's X11 platform probe doesn't hang
	# (no display server in a headless container). Xvfb also enables running
	# Flutter Linux desktop apps headlessly for testing.
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

	# D-Bus session bus (required by AT-SPI2 accessibility registry).
	# Must start before the MCP server so it inherits the bus address.
	# Check both that the env var is set AND that the bus is reachable;
	# a stale env var from a dead dbus-daemon must not skip re-launch.
	if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] || \
			! dbus-send --session --dest=org.freedesktop.DBus --print-reply \
				/org/freedesktop/DBus org.freedesktop.DBus.Peer.Ping &>/dev/null; then
		eval "$(dbus-launch --sh-syntax)"
		export DBUS_SESSION_BUS_ADDRESS
	fi

	# Unlock gnome-keyring with an empty password so flutter_secure_storage
	# can store/retrieve secrets (e.g. desktop app pairing secret).
	# Must run immediately after dbus-launch before triggering automatic
	# dbus activiation of a locked keyring daemon
	if command -v gnome-keyring-daemon >/dev/null 2>&1; then
		echo "" | gnome-keyring-daemon --unlock --replace
	fi

	# AT-SPI2 accessibility stack (enables MCP ui_tree for GTK apps).
	# The bus launcher creates the accessibility bus socket; the registryd
	# connects to it.  Both are needed — registryd alone fails without the bus.
	if [ -x /usr/libexec/at-spi-bus-launcher ] && \
			! pgrep -x at-spi-bus-lau >/dev/null 2>&1; then
		DISPLAY=:99 /usr/libexec/at-spi-bus-launcher --launch-immediately &>/dev/null &
		sleep 1
	fi
	if [ -x /usr/libexec/at-spi2-registryd ] && \
			! pgrep -x at-spi2-registr >/dev/null 2>&1; then
		DISPLAY=:99 /usr/libexec/at-spi2-registryd &>/dev/null &
	fi

	# Openbox window manager (proper GTK window sizing/decorations on Xvfb)
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
