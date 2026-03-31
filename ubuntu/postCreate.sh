#!/bin/bash

set -e

# ┌─────┐
# │ Act │ (run GitHub Actions locally)
# └─────┘

curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash -s -- -b /usr/local/bin

# ┌──────────┐
# │ Lefthook │
# └──────────┘

LEFTHOOK_VERSION=$(curl -fsSL https://api.github.com/repos/evilmartians/lefthook/releases/latest | grep -o '"tag_name": "v[^"]*"' | grep -o '[0-9][^"]*')
LEFTHOOK_DEB=$(mktemp)
curl -fsSL -o "$LEFTHOOK_DEB" "https://github.com/evilmartians/lefthook/releases/download/v${LEFTHOOK_VERSION}/lefthook_${LEFTHOOK_VERSION}_amd64.deb"
sudo dpkg -i "$LEFTHOOK_DEB"
rm "$LEFTHOOK_DEB"

# ┌─────┐
# │ Bun │
# └─────┘

curl -fsSL https://bun.sh/install | bash
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ┌─────┐
# │ fnm │
# └─────┘

curl -fsSL https://fnm.vercel.app/install | bash

FNM_PATH="/home/vscode/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell bash)"
fi

# ┌─────────────┐
# │ Claude Code │
# └─────────────┘

## Config

# bind mounted ~/.claude/.credentials.json so need to update ~/.claude permissions
sudo chown $USER ~/.claude
sudo chgrp $USER ~/.claude

# Copy statusline.sh staged by hostConfig.sh into the container
if [ -f .devcontainer/ubuntu/statusline.sh ]; then
  cp .devcontainer/ubuntu/statusline.sh ~/.claude/statusline.sh
  rm .devcontainer/ubuntu/statusline.sh
fi

# Configure statusline in user-level settings
if [ -f ~/.claude/statusline.sh ]; then
  mkdir -p ~/.claude
  SETTINGS=~/.claude/settings.json
  if [ -f "$SETTINGS" ]; then
    # Merge statusLine into existing settings
    jq '. + {"statusLine": {"type": "command", "command": "bash ~/.claude/statusline.sh"}}' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  else
    cat > "$SETTINGS" <<'EOSETTINGS'
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
EOSETTINGS
  fi
fi

# sudo apt install -y moreutils > /dev/null
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

echo 'claude --permission-mode bypassPermissions' >> ~/.bash_history

## Install Claude Code

curl -fsSL https://claude.ai/install.sh | bash
