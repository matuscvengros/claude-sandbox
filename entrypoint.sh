#!/bin/bash
set -e

export HOME=/home/claude

# Shared setup: SSH key + git identity
source /home/claude/scripts/setup-credentials.sh
rm -f /home/claude/scripts/setup-credentials.sh

# Pass all arguments through to claude
exec claude "$@"
