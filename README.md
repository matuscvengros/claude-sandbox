# Claude Docker Sandbox

Docker container for running Claude Code autonomously on Ubuntu 24.04 LTS. Built for macOS hosts using OrbStack where Docker Sandbox isn't available.

## Variants

| Profile | Permissions | Host access | Use case |
|---------|------------|-------------|----------|
| `default` | Autonomous (no prompts) | R/W project + read-only `$HOME` | Full autonomous development |
| `safe` | Autonomous (no prompts) | R/W project only | Sandboxed project work |

## Pre-installed tools

- Node.js 22 (LTS) + npm
- Python 3 + pip + venv
- Rust (rustup)
- C/C++ (gcc, g++, make, cmake, build-essential)
- Git, curl, ripgrep, fd, jq
- Starship prompt (Gruvbox Rainbow)

## Setup

1. Copy `.env.example` to `.env` and fill in your values:
   ```
   CLAUDE_SETUP_TOKEN=<your-token>
   GIT_USER_NAME=Your Name
   GIT_USER_EMAIL=you@example.com
   SSH_PRIVATE_KEY_B64=<base64 -i ~/.ssh/id_ed25519>
   ```

2. Place any custom plugins in `plugins/` before building.

3. Build:
   ```bash
   docker compose --profile default build
   docker compose --profile safe build
   ```

## Usage

Interactive mode:
```bash
docker compose --profile default run --rm claude
docker compose --profile safe run --rm claude-safe
```

Prompt mode:
```bash
docker compose --profile default run --rm claude "build a REST API for todos"
```

### Aliases

Add to your shell profile for seamless usage:
```bash
alias claudesb='docker compose -f ~/Documents/projects/claude-docker/docker-compose.yml --profile default run --rm claude'
alias claudesafe='docker compose -f ~/Documents/projects/claude-docker/docker-compose.yml --profile safe run --rm claude-safe'
```

Then from any project directory:
```bash
cd ~/my-project
claudesb
```

## Mount layout (default profile)

| Container path | Host source | Access |
|---------------|-------------|--------|
| `/home/claude/project` | Caller's `$PWD` | Read/Write |
| `/host/home` | `$HOME` | Read-only |

## Plugins

Place plugin directories in `plugins/` before building. They are copied into the image at `/home/claude/.claude/plugins/`.
