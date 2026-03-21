# Claude Code Docker Sandbox

[![Docker](https://img.shields.io/badge/Docker-node%3A22-blue?logo=docker)](https://hub.docker.com/_/node)
[![Build](https://github.com/matuscvengros/claude-docker-sandbox/actions/workflows/build.yml/badge.svg)](https://github.com/matuscvengros/claude-docker-sandbox/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Docker container for running Claude Code autonomously. Based on `node:22` (Debian Bookworm). Built for macOS hosts using OrbStack where Docker Sandbox isn't available.

## Pre-installed tools

- Node.js 22 (LTS) + npm
- Python 3 + pip + venv
- C/C++ (gcc, g++, make, cmake, build-essential)
- Git, curl, ripgrep, fd, jq, openssh-client
- Starship prompt (Bracketed Segments)

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

You can get a token by running `claude set-token` on your host machine, or from an existing session.

### 3. Configure git identity and SSH (optional)

```bash
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=you@example.com

# For git push/pull over SSH (base64-encoded private key)
# Generate with: base64 -i ~/.ssh/id_ed25519
SSH_PRIVATE_KEY_B64=
```

### 4. Build

```bash
docker compose build
```

The compose file is configured to build the `full` target (base + private plugins) and forward your SSH agent automatically. If you don't have private plugins, the build still works — `private-build/claude-plugins.sh` controls what gets installed.

To build without private plugins (e.g., no SSH agent available):
```bash
docker build --target base -t claude-docker-sandbox .
```

## Usage

### Standalone (headless / CLI)

Interactive mode:
```bash
docker compose run --rm claude-sandbox
```

Prompt mode:
```bash
docker compose run --rm claude-sandbox -- -p "build a REST API for todos"
```

Passing flags (use `--` to separate docker flags from claude flags):
```bash
docker compose run --rm claude-sandbox -- --model opus
docker compose run --rm claude-sandbox -- --model opus -p "build a REST API"
```

> Use `--rm` to automatically remove the container after it exits.

### DevContainer (VS Code / Cursor)

Open this repo (or any project containing `.devcontainer/`) in VS Code and select **"Reopen in Container"**. The container stays running while the IDE is open. Open a terminal to launch Claude:

```bash
claude
```

### Aliases

Add to your shell profile for seamless usage (adjust the path to where you cloned this repo):
```bash
CLAUDE_DOCKER="$HOME/path/to/claude-docker-sandbox"
alias sandbox="docker compose -f $CLAUDE_DOCKER/docker-compose.yml run --rm claude-sandbox"
alias cc="docker compose -f $CLAUDE_DOCKER/docker-compose.yml run --rm claude-sandbox -- --model opus"
```

Then from any project directory:
```bash
cd ~/my-project
sandbox             # interactive, default model
cc                  # interactive, opus model
cc -p "fix the bug" # prompt mode, opus model
```

## Standalone vs DevContainer

| Aspect | Standalone | DevContainer |
|--------|-----------|--------------|
| **Use case** | Headless, fire-and-forget tasks | Interactive development with IDE |
| **Launch** | `docker compose run --rm claude-sandbox` | "Reopen in Container" in VS Code |
| **Lifecycle** | Ephemeral — dies after Claude exits | Persistent while IDE is open |
| **IDE features** | None — pure terminal | Extensions, debugger, source control |
| **Claude launch** | Automatic via entrypoint | Manual in terminal |

Use both together: devcontainer for interactive work, standalone alias for fire-and-forget tasks on other projects.

## Session persistence

Containers are ephemeral by default — Claude Code state (conversation history, project memory) is lost when the container exits. To persist sessions across runs, uncomment the volume mount in `docker-compose.yml`:

```yaml
# Share host config folder for session persistence
- ${HOME}/.claude.sandbox:/home/claude/.claude
```

This maps a host directory to the container's Claude config folder. Use a dedicated directory (e.g., `~/.claude.sandbox`) to keep it separate from your host's Claude config.

## Mount layout

| Container path | Host source | Access |
|---------------|-------------|--------|
| `/home/claude/project` | Caller's `$PWD` (standalone) or opened folder (devcontainer) | Read/Write |
| `/home/host` | `$HOME` | Read-only (secrets masked) |

Sensitive host directories (`.ssh`, `.config`, `.docker`, `.orbstack`, `Library/Keychains`) are masked with empty tmpfs overlays to prevent container access.

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Yes | OAuth token — picked up automatically by Claude CLI |
| `GIT_USER_NAME` | No | Git committer name |
| `GIT_USER_EMAIL` | No | Git committer email |
| `SSH_PRIVATE_KEY_B64` | No | Base64-encoded SSH private key (`base64 -i ~/.ssh/id_ed25519`) |

## Private plugins

The Dockerfile uses two build stages:

| Target | Contents | Used by |
|--------|----------|---------|
| `base` | System packages, Claude CLI, official plugins | CI workflow |
| `full` | Everything in `base` + private plugins via SSH | `docker compose build` (local) |

See `private-build/claude-plugins.sh.example` for the template. Copy it to `private-build/claude-plugins.sh` and add your plugin commands. The compose files forward your SSH agent automatically.
