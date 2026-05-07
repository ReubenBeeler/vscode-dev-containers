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

	echo ┌─\────────────────────────┐
	echo │ ✅  Completed PostCreate │
	echo └─\────────────────────────┘

	exit 0
}
