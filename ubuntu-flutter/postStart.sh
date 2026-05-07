#!/usr/bin/env bash
# postStart.sh — starts runtime services on every container start.
# All starts are idempotent (pgrep/command-v guarded), so this script is
# safe to call multiple times (e.g. inline from postCreate.sh).
{ # prevents execution from breaking from concurrent modification
	set -euo pipefail
	
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
		Xvfb :99 -screen 0 1024x768x24 &>/dev/null &
	fi
	export DISPLAY=:99

	# D-Bus session bus (required by AT-SPI2 accessibility registry).
	# Must start before the MCP server so it inherits the bus address.
	if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
		eval "$(dbus-launch --sh-syntax)"
		export DBUS_SESSION_BUS_ADDRESS
	fi

	# AT-SPI2 accessibility registry (enables MCP ui_tree for GTK apps)
	if [ -x /usr/libexec/at-spi2-registryd ] && \
			! pgrep -f at-spi2-registryd >/dev/null 2>&1; then
		/usr/libexec/at-spi2-registryd &>/dev/null &
	fi

	# Openbox window manager (proper GTK window sizing/decorations on Xvfb)
	if command -v openbox >/dev/null 2>&1 && ! pgrep -x openbox >/dev/null 2>&1; then
		DISPLAY=:99 openbox &>/dev/null &
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
