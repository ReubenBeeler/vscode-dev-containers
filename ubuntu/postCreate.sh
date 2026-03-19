#!/bin/bash

set -e

# ┌─────┐
# │ Act │ (run GitHub Actions locally)
# └─────┘

curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
sudo mv bin/act /usr/local/bin
rmdir bin

# ┌─────┐
# │ Bun │
# └─────┘

curl -fsSL https://bun.sh/install | bash	# Auto-adds bun to PATH in ~/.bashrc
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

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

bunx --yes @kamranahmedse/claude-statusline
