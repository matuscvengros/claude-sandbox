# Claude Code Docker Sandbox

[![Docker](https://img.shields.io/badge/Docker-node%3A22-blue?logo=docker)](https://hub.docker.com/_/node)
[![Build](https://github.com/matuscvengros/claude-docker-sandbox/actions/workflows/build.yml/badge.svg)](https://github.com/matuscvengros/claude-docker-sandbox/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Docker container for running Claude Code autonomously in an isolated sandbox. Based on `node:22` (Debian Bookworm). Built for macOS hosts using OrbStack where Docker Sandbox isn't available.

## Pre-installed tools

- Node.js 22 (LTS) + npm
- Python 3 + pip + venv
- C/C++ (gcc, g++, make, cmake, build-essential)
- Git, curl, wget, ripgrep, fd-find, jq, openssh-client
- Starship prompt (Bracketed Segments preset)
- Claude Code CLI with official plugins (superpowers, firecrawl, playwright, code-review, and more)

## Setup

### 1. Create your `.env` file

```bash
cp .env.example .env
```

### 2. Configure authentication

Set `CLAUDE_CODE_OAUTH_TOKEN` in your `.env` file. Claude CLI picks this up automatically from the environment.

```bash
CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...
```

You can get a token by running `claude set-token` on your host machine.

### 3. Configure git identity (optional)

```bash
GIT_USER_NAME="Your Name"
GIT_USER_EMAIL="you@example.com"
```

### 4. Build

```bash
docker compose build
```

This builds the `base` target — system packages, Claude CLI, and official plugins. Ready to use out of the box.

To include private plugins, build the `full` target and ensure your SSH keys are loaded in `ssh-add` (see [Private plugins](#private-plugins)):

```bash
BUILD_TARGET=full docker compose build
```

To rebuild from scratch (no cache):

```bash
docker compose build --no-cache                  # base
BUILD_TARGET=full docker compose build --no-cache # full
```

## Shell aliases

Add these to your `~/.bashrc` or `~/.zshrc` for seamless usage from any directory:

```bash
CLAUDE_DOCKER="$HOME/path/to/claude-docker-sandbox"

# Isolated sandbox — ephemeral, no state persisted between runs
alias cc="docker compose -f $CLAUDE_DOCKER/docker-compose.yml run --rm claude-sandbox claude"

# Drop into a shell instead of Claude
alias ccbash="docker compose -f $CLAUDE_DOCKER/docker-compose.yml run --rm claude-sandbox bash"

# Shared sandbox — persists Claude state (memory, sessions, plugins) across runs
alias ccshared="docker compose -f $CLAUDE_DOCKER/docker-compose.yml run --rm -v $HOME/.claude.sandbox:/home/claude/.claude claude-sandbox claude"
```

Then from any project directory:

```bash
cd ~/my-project

cc                            # interactive, isolated
cc -- -p "build a REST API"   # prompt mode, isolated
cc -- --model sonnet          # override default model

ccbash                        # shell access, isolated
ccshared                      # interactive, persistent state
ccshared -- -p "continue"     # prompt mode, persistent state
```

**`cc`** gives you a clean, disposable sandbox every time — Claude starts fresh with no memory of previous sessions.

**`ccbash`** drops you into a bash shell inside the sandbox for manual inspection or setup.

**`ccshared`** maps `~/.claude.sandbox` on your host to the container's Claude config directory. This preserves conversation history, project memory, and plugin state across runs. The directory is created automatically on first use.

## Usage

### Standalone (headless / CLI)

Without aliases:

```bash
# Interactive
docker compose run --rm claude-sandbox

# Prompt mode
docker compose run --rm claude-sandbox -- -p "build a REST API for todos"

# Override model
docker compose run --rm claude-sandbox -- --model sonnet -p "build a REST API"
```

Use `--` to separate Docker flags from Claude flags. Use `--rm` to automatically remove the container after it exits.

### DevContainer (VS Code / Cursor)

Open this repo (or any project containing `.devcontainer/`) in VS Code and select **"Reopen in Container"**. The container stays running while the IDE is open. Open a terminal and launch Claude:

```bash
claude
```

### Standalone vs DevContainer

| Aspect | Standalone | DevContainer |
|--------|-----------|--------------|
| **Use case** | Headless, fire-and-forget tasks | Interactive development with IDE |
| **Launch** | `cc` / `docker compose run --rm ...` | "Reopen in Container" in VS Code |
| **Lifecycle** | Ephemeral — dies after Claude exits | Persistent while IDE is open |
| **IDE features** | None — pure terminal | Extensions, debugger, source control |
| **Claude launch** | Automatic via entrypoint | Manual in terminal |

## SSH & authentication

### SSH in the running container

SSH keys are only needed if you want Claude to perform git operations over SSH (push, pull, clone) inside the container. Two methods are supported, with agent forwarding preferred:

**1. SSH agent forwarding (recommended)**

If your host has an SSH agent running (`ssh-add -l` shows keys), it is automatically forwarded into the container. No configuration needed — the compose file mounts the host's `SSH_AUTH_SOCK` into the container.

```bash
# Verify your agent has keys loaded
ssh-add -l
```

**2. Base64-encoded key (fallback)**

If your host has no SSH agent (e.g., in CI), provide a base64-encoded private key in `.env`:

```bash
# Generate with:
base64 -i ~/.ssh/id_ed25519

# Then set in .env:
SSH_PRIVATE_KEY_B64=<base64-encoded-key>
```

The key is decoded at container startup, written to `~/.ssh/id_ed25519` with `600` permissions, and available for git operations. Agent forwarding takes priority if both are configured.

### SSH during build (private plugins)

The `full` build target uses Docker BuildKit SSH forwarding to clone private plugin repositories. BuildKit mounts the host's SSH agent socket during the build — the key material never enters the image layers.

This requires your SSH keys to be loaded in `ssh-add` on the host:

```bash
# Load your key (if not already loaded)
ssh-add ~/.ssh/id_ed25519

# Then build the full target
BUILD_TARGET=full docker compose build
```

If you don't have keys in `ssh-add` and need to pull private repos during build, you'll need to add them first, or provide a specific key to the agent.

### Known hosts

The file `ssh/known_hosts` contains GitHub's published SSH host keys (RSA, ECDSA, Ed25519). These are copied into the container at build time to prevent interactive "Are you sure you want to continue connecting?" prompts. The keys can be verified against [GitHub's published fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints).

If you need to connect to other SSH hosts (GitLab, Bitbucket, self-hosted), add their keys to `ssh/known_hosts` before building.

## Private plugins

The Dockerfile uses two build stages:

| Target | Contents | Used by |
|--------|----------|---------|
| `base` | System packages, Claude CLI, official plugins | `docker compose build` (default) |
| `full` | Everything in `base` + private plugins via SSH | `BUILD_TARGET=full docker compose build` |

To add private plugins, copy the example and add your plugin commands:

```bash
cp private-build/claude-plugins.sh.example private-build/claude-plugins.sh
```

Edit `private-build/claude-plugins.sh` to install your plugins:

```bash
#!/bin/bash
set -e
export SSH_AUTH_SOCK=$(ls /run/buildkit/ssh_agent.* 2>/dev/null | head -1)

claude plugin marketplace add git@github.com:your-org/your-plugins.git
claude plugin install your-plugin@your-plugins
```

The script runs during the `full` build stage with the host's SSH agent forwarded, allowing access to private repositories.

## Mount layout & security

| Container path | Host source | Access | Purpose |
|---------------|-------------|--------|---------|
| `/home/claude/project` | Caller's `$PWD` | Read/Write | Project workspace |
| `/home/host` | `$HOME` | Read-only | Host home directory |
| `/ssh-agent` | Host's `$SSH_AUTH_SOCK` | Read-only | SSH agent forwarding |

Sensitive host directories are masked with empty tmpfs overlays to prevent container access:

- `/home/host/.ssh` — SSH keys and config
- `/home/host/.config` — application configurations
- `/home/host/.docker` — Docker credentials
- `/home/host/.orbstack` — OrbStack configuration
- `/home/host/Library/Keychains` — macOS keychains
- `/home/host/.npmrc` — npm credentials (mounted as `/dev/null`)

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Yes | OAuth token for Claude CLI authentication |
| `GIT_USER_NAME` | No | Git committer name |
| `GIT_USER_EMAIL` | No | Git committer email |
| `SSH_PRIVATE_KEY_B64` | No | Base64-encoded SSH private key (fallback if no SSH agent) |

## Container defaults

The container ships with these Claude Code defaults (configured in `claude/settings.json`):

- **Model:** `opus`
- **Permissions:** `bypassPermissions` (autonomous mode) with `.env` files denied
- **Onboarding:** Skipped (pre-configured in `claude/.claude.json`)
- **Auto-updates:** Disabled
