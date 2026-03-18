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
  ssh-keyscan github.com gitlab.com >> /home/claude/.ssh/known_hosts 2>/dev/null
fi

if [ $# -gt 0 ]; then
  # Prompt mode: run non-interactively with a single string argument
  exec claude --dangerously-skip-permissions -p "$1"
else
  # Interactive mode: drop into Claude REPL
  exec claude --dangerously-skip-permissions
fi
