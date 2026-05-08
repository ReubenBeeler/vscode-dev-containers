#!/usr/bin/env bash
# postCreate.sh — runs once at container creation via devcontainer.json
# postCreateCommand. At this point bind mounts and the workspace are available.
{ # prevents execution from breaking from concurrent modification
	set -euo pipefail

	echo ┌─────────────┐
	echo │ Claude Code │
	echo └─────────────┘

	sudo chown $USER ~/.claude
	sudo chgrp $USER ~/.claude

	echo ┌──────────────────────────────────────────────┐
	echo │ Disable IPv6 \(no connectivity in container\) │
	echo └──────────────────────────────────────────────┘

	# The container has IPv6 interfaces but no IPv6 internet connectivity.
	# Java/Gradle prefer IPv6 by default, causing DNS resolution failures
	# (UnknownHostException) when downloading dependencies.
	sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
	sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1

	echo ┌─\────────────────────────┐
	echo │ ✅  Completed PostCreate │
	echo └─\────────────────────────┘

	exit 0
}
