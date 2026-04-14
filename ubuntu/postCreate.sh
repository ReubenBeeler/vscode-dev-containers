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

# ┌──────┐
# │ Deno │
# └──────┘

curl -fsSL https://deno.land/install.sh | sh -s -- -y
DENO_PATH_LINE='export DENO_INSTALL="$HOME/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"'
grep -qF 'DENO_INSTALL' ~/.bashrc  || printf '\n%s\n' "$DENO_PATH_LINE" >> ~/.bashrc
grep -qF 'DENO_INSTALL' ~/.profile || printf '\n%s\n' "$DENO_PATH_LINE" >> ~/.profile
export DENO_INSTALL="$HOME/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

COMPLETIONS_DIR="$HOME/.local/share/bash-completion/completions"
mkdir -p "$COMPLETIONS_DIR"
deno completions bash > "$COMPLETIONS_DIR/deno"

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

# sanity
mkdir -p ~/.claude

# bind mounted ~/.claude/.credentials.json so need to update ~/.claude permissions
sudo chown $USER ~/.claude
sudo chgrp $USER ~/.claude

# Copy statusline.sh staged by hostConfig.sh into the container
STATUSLINE_PATH='.devcontainer/ubuntu-flutter/statusline.sh'
if [ -f "$STATUSLINE_PATH" ]; then
	mv "$STATUSLINE_PATH" ~/.claude/statusline.sh
fi

# Configure statusline in user-level settings
if [ -f ~/.claude/statusline.sh ]; then
	SETTINGS_PATH=~/.claude/settings.json
	SETTINGS_JSON=\
'{
	"env": {
		"DISABLE_AUTOUPDATER": "1"
	},
	"statusLine": {
		"type": "command",
		"command": "bash ~/.claude/statusline.sh"
	},
	"skipDangerousModePermissionPrompt": true
}'
	if [ -f "$SETTINGS_PATH" ]; then
		# Merge statusLine into existing settings
		jq ". + $SETTINGS_JSON" "$SETTINGS_PATH" | sponge "$SETTINGS_PATH"
	else
		echo "$SETTINGS_JSON" > "$SETTINGS_PATH"
	fi
fi

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

curl -fsSL https://claude.ai/install.sh | bash -s 2.1.68  # old version should fix caching issues
# see {"env": {"DISABLE_AUTOUPDATER": "1"}} in settings json for version pin

## Claude Code Extensions