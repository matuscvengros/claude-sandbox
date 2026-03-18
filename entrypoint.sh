#!/bin/bash
set -e

export HOME=/home/claude

# Override git identity if env vars are provided
[ -n "$GIT_USER_NAME" ] && git config --global user.name "$GIT_USER_NAME"
[ -n "$GIT_USER_EMAIL" ] && git config --global user.email "$GIT_USER_EMAIL"

# Recreate SSH key from base64-encoded env var
if [ -n "$SSH_PRIVATE_KEY_B64" ]; then
  mkdir -p /home/claude/.ssh
  echo "$SSH_PRIVATE_KEY_B64" | base64 -d > /home/claude/.ssh/id_ed25519
  chmod 700 /home/claude/.ssh
  chmod 600 /home/claude/.ssh/id_ed25519
fi

# Pass all arguments through to claude
exec claude --dangerously-skip-permissions "$@"
