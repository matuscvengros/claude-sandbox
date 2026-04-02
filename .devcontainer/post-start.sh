#!/bin/bash
set -e

export HOME=/home/claude

# Shared setup: SSH key + git identity
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/scripts/setup-credentials.sh"
