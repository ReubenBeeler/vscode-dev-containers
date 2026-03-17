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
