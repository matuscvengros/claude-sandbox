#!/bin/bash
# Shared credential setup — sourced by entrypoint.sh and post-start.sh

# SSH: prefer forwarded agent, fall back to base64-encoded key
if [ -S "$SSH_AUTH_SOCK" ] && sudo ssh-add -l &>/dev/null; then
  # Proxy the host socket via socat so the claude user can access it
  # without modifying permissions on the host's original socket
  PROXY_SOCK="/home/claude/.ssh/agent.sock"
  rm -f "$PROXY_SOCK"
  sudo socat UNIX-LISTEN:"$PROXY_SOCK",fork,user=claude,group=claude,mode=600 \
    UNIX-CONNECT:"$SSH_AUTH_SOCK" &
  # Wait for proxy socket to be ready
  for i in $(seq 1 10); do [ -S "$PROXY_SOCK" ] && break; sleep 0.1; done
  export SSH_AUTH_SOCK="$PROXY_SOCK"
elif [ -n "$SSH_PRIVATE_KEY_B64" ]; then
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
