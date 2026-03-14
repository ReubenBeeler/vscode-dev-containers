#!/bin/bash

set -e

# ┌─────┐
# │ Bun │
# └─────┘

curl -fsSL https://bun.sh/install | bash	# Auto-adds bun to PATH in ~/.bashrc
export PATH="$HOME/.bun/bin:$PATH"			# Add bun to PATH for this current shell

# ┌─────────────┐
# │ Claude Code │
# └─────────────┘

## Config

mkdir -p ~/.claude
cp /tmp/claude-credentials.json ~/.claude/.credentials.json

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

bunx --yes @kamranahmedse/claude-statusline

# claude-in-mobile MCP server (https://github.com/AlexGladkov/claude-in-mobile)
claude mcp add --scope user --transport stdio mobile -- bunx -y claude-in-mobile