# Coding Agent Docker Sandbox

Docker container for running coding agents (Claude Code, OpenCode, Aider, etc.) autonomously. Based on `node:22` (Debian Bookworm). Built for macOS hosts using OrbStack where Docker Sandbox isn't available.

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
   CODING_AGENT=claude
   ```

2. Build:
   ```bash
   docker compose build
   ```

## Usage

### Standalone (headless / CLI)

Interactive mode:
```bash
docker compose run --rm sandbox
```

Prompt mode:
```bash
docker compose run --rm sandbox -- -p "build a REST API for todos"
```

Passing flags (use `--` to separate docker flags from agent flags):
```bash
docker compose run --rm sandbox -- --model opus
docker compose run --rm sandbox -- --model opus -p "build a REST API"
```

Using a different coding agent:
```bash
CODING_AGENT=opencode docker compose run --rm sandbox
```

> Use `--rm` to automatically remove the container after it exits.

### DevContainer (VS Code / Cursor)

Open this repo (or any project containing `.devcontainer/`) in VS Code and select **"Reopen in Container"**. The container stays running while the IDE is open. Open a terminal to launch your coding agent manually:

```bash
claude --dangerously-skip-permissions
```

### Aliases

Add to your shell profile for seamless usage:
```bash
alias sandbox='docker compose -f ~/Documents/projects/claude-docker/docker-compose.yml run --rm sandbox'
alias cc='docker compose -f ~/Documents/projects/claude-docker/docker-compose.yml run --rm sandbox -- --model opus'
```

Then from any project directory:
```bash
cd ~/my-project
sandbox             # interactive, default agent
cc                  # interactive, claude opus
cc -p "fix the bug" # prompt mode, claude opus
```

## Standalone vs DevContainer

| Aspect | Standalone | DevContainer |
|--------|-----------|--------------|
| **Use case** | Headless, fire-and-forget tasks | Interactive development with IDE |
| **Launch** | `docker compose run --rm sandbox` | "Reopen in Container" in VS Code |
| **Lifecycle** | Ephemeral — dies after agent exits | Persistent while IDE is open |
| **IDE features** | None — pure terminal | Extensions, debugger, source control |
| **Agent launch** | Automatic via entrypoint | Manual in terminal |

Use both together: devcontainer for interactive work, standalone alias for fire-and-forget tasks on other projects.

## Mount layout

| Container path | Host source | Access |
|---------------|-------------|--------|
| `/home/node/project` | Caller's `$PWD` (standalone) or opened folder (devcontainer) | Read/Write |
| `/home/host` | `$HOME` | Read-only (secrets masked) |

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ANTHROPIC_AUTH_TOKEN` | Yes | Claude API authentication token |
| `SSH_PRIVATE_KEY_B64` | No | Base64-encoded SSH private key (`base64 -i ~/.ssh/id_ed25519`) |
| `CODING_AGENT` | No | Agent to run (default: `claude`). Options: `claude`, `opencode`, `aider`, etc. |
