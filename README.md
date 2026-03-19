# Claude Code Docker Sandbox

[![Build](https://github.com/matuscvengros/claude-docker-sandbox/actions/workflows/build.yml/badge.svg)](https://github.com/matuscvengros/claude-docker-sandbox/actions/workflows/build.yml)
[![Docker](https://img.shields.io/badge/Docker-node%3A22-blue?logo=docker)](https://hub.docker.com/_/node)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Docker container for running Claude Code autonomously. Based on `node:22` (Debian Bookworm). Built for macOS hosts using OrbStack where Docker Sandbox isn't available.

## Pre-installed tools

- Node.js 22 (LTS) + npm
- Python 3 + pip + venv
- Rust (rustup)
- C/C++ (gcc, g++, make, cmake, build-essential)
- Git, curl, ripgrep, fd, jq, openssh-client
- Starship prompt (Bracketed Segments)

## Setup

1. Copy `.env.example` to `.env` and fill in your values:
   ```
   ANTHROPIC_AUTH_TOKEN=<your-token>
   SSH_PRIVATE_KEY_B64=<output of: base64 -i ~/.ssh/id_ed25519>
   ```

2. Build:
   ```bash
   docker compose build
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
claude --dangerously-skip-permissions
```

### Aliases

Add to your shell profile for seamless usage:
```bash
alias sandbox='docker compose -f ~/Documents/projects/claude-docker/docker-compose.yml run --rm claude-sandbox'
alias cc='docker compose -f ~/Documents/projects/claude-docker/docker-compose.yml run --rm claude-sandbox -- --model opus'
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

## Mount layout

| Container path | Host source | Access |
|---------------|-------------|--------|
| `/home/claude/project` | Caller's `$PWD` (standalone) or opened folder (devcontainer) | Read/Write |
| `/home/host` | `$HOME` | Read-only (secrets masked) |

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ANTHROPIC_AUTH_TOKEN` | Yes | Claude API authentication token |
| `SSH_PRIVATE_KEY_B64` | No | Base64-encoded SSH private key (`base64 -i ~/.ssh/id_ed25519`) |
