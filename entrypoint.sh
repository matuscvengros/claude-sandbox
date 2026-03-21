#!/bin/bash
set -e

export HOME=/home/claude

# Shared setup: SSH key + git identity
source /tmp/setup-credentials.sh
rm -f /tmp/setup-credentials.sh

# Pass all arguments through to claude
exec claude "$@"
