#!/bin/bash
set -e

export HOME=/home/node

# Recreate SSH key from base64-encoded env var (same as standalone entrypoint)
if [ -n "$SSH_PRIVATE_KEY_B64" ]; then
  mkdir -p /home/node/.ssh
  echo "$SSH_PRIVATE_KEY_B64" | base64 -d > /home/node/.ssh/id_ed25519
  chmod 700 /home/node/.ssh
  chmod 600 /home/node/.ssh/id_ed25519
fi
