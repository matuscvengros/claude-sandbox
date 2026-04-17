#!/bin/bash
set -e

export HOME=/home/claude

# Shared setup: SSH key + git identity
source /tmp/setup-credentials.sh
rm -f /tmp/setup-credentials.sh

# Trust the workspace directory so Claude skips the interactive prompt
source /tmp/setup-claude-workdir-trust.sh
rm -f /tmp/setup-claude-workdir-trust.sh

# Run CMD (defaults to bash — override via docker run/compose)
exec "$@"
