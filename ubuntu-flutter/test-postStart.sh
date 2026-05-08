#!/usr/bin/env bash
# test-postStart.sh — verifies postStart.sh and postCreate.sh behaved correctly.
# Run this inside the container after a rebuild.

PASS=0
FAIL=0

pass()   { echo "  ✅ $1"; ((PASS++)); }
fail() { echo "  ❌ $1"; ((FAIL++)); }

check_process() {
	local proc="$1"
	# Use -f (full command line) to handle process names longer than 15 chars
	# (Linux truncates comm names at 15, breaking pgrep -x for longer names).
	if pgrep -f "$proc" >/dev/null 2>&1; then
		pass "$proc is running ($(pgrep -f "$proc" | head -1))"
	else
		fail "$proc is NOT running"
	fi
}

# ── DNS ───────────────────────────────────────────────────────────────────────

echo
echo "── DNS ────────────────────────────────────────────────────────────────────"

if grep -q 'single-request-reopen' /etc/resolv.conf 2>/dev/null; then
	pass "resolv.conf has single-request-reopen"
else
	fail "resolv.conf missing single-request-reopen"
fi

ns_count=$(grep -c '^nameserver' /etc/resolv.conf 2>/dev/null || echo 0)
if [ "$ns_count" -ge 2 ]; then
	pass "$ns_count nameservers configured (fallback available)"
else
	fail "only $ns_count nameserver configured (no fallback)"
fi

if getent hosts google.com >/dev/null 2>&1; then
	pass "DNS resolution works (google.com)"
else
	fail "DNS resolution failed (google.com)"
fi

# ── udevd ─────────────────────────────────────────────────────────────────────

echo
echo "── udevd ──────────────────────────────────────────────────────────────────"

check_process "systemd-udevd"

if [ -d /dev/bus/usb ]; then
	pass "/dev/bus/usb exists"
else
	fail "/dev/bus/usb does not exist"
fi

if [ -f /etc/udev/rules.d/99-usb-open-access.rules ]; then
	pass "udev rule file exists"
else
	fail "udev rule file /etc/udev/rules.d/99-usb-open-access.rules missing"
fi

# ── Headless desktop ───────────────────────────────────────────────────────────

echo
echo "── Headless desktop ───────────────────────────────────────────────────────"

check_process "Xvfb"

if [ "${DISPLAY:-}" = ":99" ]; then
	pass "DISPLAY=:99"
else
	fail "DISPLAY is '${DISPLAY:-<unset>}' (expected :99)"
fi

if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
	pass "DBUS_SESSION_BUS_ADDRESS is set"
else
	fail "DBUS_SESSION_BUS_ADDRESS is unset"
fi

check_process "at-spi2-registryd"
check_process "openbox"

# ── Summary ────────────────────────────────────────────────────────────────────

echo
echo "── Summary ────────────────────────────────────────────────────────────────"
echo "  Passed: $PASS  Failed: $FAIL"
echo

if [ "$FAIL" -gt 0 ]; then
	exit 1
fi
