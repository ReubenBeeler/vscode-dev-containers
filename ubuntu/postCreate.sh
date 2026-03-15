#!/bin/bash

set -e

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

# agent orchestration
bunx ruflo init

# status line
bunx --yes @kamranahmedse/claude-statusline

# mobile dev MCP server (https://github.com/AlexGladkov/claude-in-mobile)
claude mcp add --scope user --transport stdio mobile -- bunx -y claude-in-mobile
