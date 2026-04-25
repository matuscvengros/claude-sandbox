#!/bin/bash
set -e

export HOME=/home/agent
export WORKSPACE="$(pwd)"

# Shared setup: SSH key + git identity
source /tmp/setup-credentials.sh
rm -f /tmp/setup-credentials.sh

# Trust the workspace directory so Claude skips the interactive prompt
source /tmp/setup-claude-workdir-trust.sh
rm -f /tmp/setup-claude-workdir-trust.sh

# Trust the workspace directory so Codex skips the interactive prompt
source /tmp/setup-codex-workdir-trust.sh
rm -f /tmp/setup-codex-workdir-trust.sh

# Symlink the workspace into the home directory under its basename for easier access
# (e.g., PWD=/Users/you/workdir → ~/workdir). Skipped when the workspace already is
# the home directory, or when a name collision exists at the link path.
LINK="$HOME/$(basename "$WORKSPACE")"
if [ "$WORKSPACE" != "$HOME" ] && [ ! -e "$LINK" ]; then
  ln -s "$WORKSPACE" "$LINK"
fi

# Run CMD (defaults to bash — override via docker run/compose)
exec "$@"
