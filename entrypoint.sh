#!/bin/bash
set -e

export HOME=/home/claude

# Recreate SSH key from base64-encoded env var
if [ -n "$SSH_PRIVATE_KEY_B64" ]; then
  mkdir -p /home/claude/.ssh
  echo "$SSH_PRIVATE_KEY_B64" | base64 -d > /home/claude/.ssh/id_ed25519
  chmod 600 /home/claude/.ssh/id_ed25519
fi

# Configure git identity from env vars
if [ -n "$GIT_USER_NAME" ]; then
  git config --global user.name "$GIT_USER_NAME"
fi
if [ -n "$GIT_USER_EMAIL" ]; then
  git config --global user.email "$GIT_USER_EMAIL"
fi

# Pass all arguments through to claude
exec claude --dangerously-skip-permissions "$@"
