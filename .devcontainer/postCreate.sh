#!/bin/bash

set -e

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


sudo npm install -g npm
npx --yes @kamranahmedse/claude-statusline