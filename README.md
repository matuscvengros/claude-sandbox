# Docker Sandbox for Claude Code

[![Docker](https://img.shields.io/badge/Docker-node%3A24-blue?logo=docker)](https://hub.docker.com/_/node)
[![Build](https://github.com/matuscvengros/claude-docker-sandbox/actions/workflows/build.yml/badge.svg)](https://github.com/matuscvengros/claude-docker-sandbox/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Docker container for running Claude Code autonomously in an isolated sandbox. Based on `node:24` (Debian Bookworm). Built for macOS hosts using OrbStack where Docker Sandbox isn't available.

## Pre-installed tools

- Node.js 24 (LTS) + npm
- Python 3 + pip + venv
- C/C++ (gcc, g++, make, cmake, build-essential)
- Git, GitHub CLI (`gh`), curl, wget, ripgrep, fd-find, jq, openssh-client
- Starship prompt (Bracketed Segments preset)
- Firecrawl CLI (`firecrawl-cli`)
- Claude Code CLI with official plugins (see [Plugins](#plugins))

## Plugins

The container ships with 24+ plugins from the [official marketplace](https://github.com/anthropics/claude-plugins-official):

| Category | Plugins |
|----------|---------|
| **Workflow & Configuration** | superpowers, claude-md-management, claude-code-setup, explanatory-output-style, learning-output-style, commit-commands, hookify, security-guidance |
| **Plugin & Skill Development** | agent-sdk-dev, mcp-server-dev, plugin-dev, skill-creator |
| **Code Quality & Development** | code-review, code-simplifier, pr-review-toolkit, feature-dev, pyright-lsp, typescript-lsp, clangd-lsp, frontend-design |
| **External Tools & Integrations** | firecrawl, playwright, context7, github |

Additionally, `claude-statusline-atomic` is installed for status line display.

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

### 3. Configure GitHub tokens (optional)

```bash
# For gh CLI commands
GITHUB_TOKEN=ghp_...

# For the GitHub MCP plugin
GITHUB_PERSONAL_ACCESS_TOKEN=ghp_...
```

The same token can be used for both if you prefer.

### 4. Configure git identity (optional)

```bash
GIT_USER_NAME="Your Name"
GIT_USER_EMAIL="you@example.com"
```

### 5. Build

The recommended setup pulls the pre-built public image from GHCR and builds your private plugins on top. Set `BASE_IMAGE` in your `.env`:

```bash
BASE_IMAGE=ghcr.io/matuscvengros/claude-sandbox:latest
```

Then build:

```bash
# Base only (default)
docker compose build --pull

# Base + private plugins
BUILD_TARGET=private docker compose build --pull
```

The `--pull` flag ensures Docker checks GHCR for a newer image. When using the `cc` shell function, `--pull` is included automatically.

**Alternative: full local build**

To build everything from scratch locally (no GHCR dependency):

```bash
# Base only (public plugins)
BASE_IMAGE=base docker compose build

# Base + private plugins
BASE_IMAGE=base BUILD_TARGET=private docker compose build
```

To rebuild from scratch (no cache):

```bash
docker compose build --no-cache
```

## Shell function

The `cc` function lets you launch the sandbox from any project directory. In persistent mode, it mounts Claude's state from a dedicated `agents` directory to keep it separate from your own config — this avoids polluting your home environment with persistent files from the container. If you'd rather share your own `~/.claude` config directly, you can modify the mount paths, but keep in mind the two environments may diverge and aren't necessarily meant to be the same.

### macOS

Expects a `/Users/agents` directory for persistent state (`sudo mkdir -p /Users/agents && sudo chown $USER:staff /Users/agents`).

```bash
echo 'export DOCKER_SANDBOX_DIR="$HOME/path/to/claude-docker-sandbox"' >> ~/.zshrc
cat shell/.zshrc >> ~/.zshrc
source ~/.zshrc
```

### Linux

Expects a `/home/agents` directory for persistent state (`sudo mkdir -p /home/agents && sudo chown $USER:$USER /home/agents`).

```bash
echo 'export DOCKER_SANDBOX_DIR="$HOME/path/to/claude-docker-sandbox"' >> ~/.bashrc
cat shell/.bashrc >> ~/.bashrc
source ~/.bashrc
```

### Usage

From any project directory:

```bash
cd ~/my-project

cc                            # build + run, persistent state
cc -- -p "build a REST API"   # prompt mode, persistent state
cc -- --model sonnet          # override default model

cc --no-build                 # skip build, use existing image
cc --no-build -is             # isolated, skip build

cc -is                        # interactive, isolated (no host state)
cc --isolated -- -p "task"    # prompt mode, isolated

cc -b                         # drop into a bash shell
cc --bash                     # same thing

cc -h                         # show help
```

**`cc`** (default) pulls the latest base image, rebuilds if needed, then mounts Claude's persistent state (`.claude`, `.claude.json`, `.config`) from the `agents` directory into the container, preserving conversation history, project memory, and plugin state across runs. Runs with `--dangerously-skip-permissions`. Use `--no-build` to skip the build step. Dangling images from previous builds are automatically cleaned up after each run.

**`cc --isolated`** gives you a clean, disposable sandbox — Claude starts fresh with no memory of previous sessions.

**`cc --bash`** drops you into a bash shell inside the sandbox for manual inspection or setup.

The current directory is automatically mounted into the container at `/home/claude/<folder-name>` (e.g., running from `~/my-project` mounts to `/home/claude/my-project`).

## Usage

### Standalone (headless / CLI)

Without the shell function:

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

The DevContainer comes with VS Code extensions for Python, Rust Analyzer, and ESLint pre-configured.

### Standalone vs DevContainer

| Aspect | Standalone | DevContainer |
|--------|-----------|--------------|
| **Use case** | Headless, fire-and-forget tasks | Interactive development with IDE |
| **Launch** | `cc` / `docker compose run --rm ...` | "Reopen in Container" in VS Code |
| **Lifecycle** | Ephemeral — dies after Claude exits | Persistent while IDE is open |
| **IDE features** | None — pure terminal | Extensions, debugger, source control |
| **Claude launch** | Automatic via entrypoint | Manual in terminal |
| **Host home access** | No | No |

## SSH & authentication

### SSH in the running container

SSH keys are only needed if you want Claude to perform git operations over SSH (push, pull, clone) inside the container. Two methods are supported, with agent forwarding preferred:

**1. SSH agent forwarding (recommended)**

If your host has an SSH agent running (`ssh-add -l` shows keys), it is automatically forwarded into the container. No configuration needed — the compose file mounts the host's `SSH_AUTH_SOCK` into the container.

```bash
# Verify your agent has keys loaded
ssh-add -l
```

The container uses `socat` to proxy the SSH agent socket, with automatic retry logic on startup.

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

The `private` build target uses Docker BuildKit SSH forwarding to clone private plugin repositories. BuildKit mounts the host's SSH agent socket during the build — the key material never enters the image layers.

This requires your SSH keys to be loaded in `ssh-add` on the host:

```bash
# Load your key (if not already loaded)
ssh-add ~/.ssh/id_ed25519

# Then build the private target
BUILD_TARGET=private docker compose build
```

If you don't have keys in `ssh-add` and need to pull private repos during build, you'll need to add them first, or provide a specific key to the agent.

### Known hosts

The file `ssh/known_hosts` contains GitHub's published SSH host keys (RSA, ECDSA, Ed25519). These are copied into the container at build time to prevent interactive "Are you sure you want to continue connecting?" prompts. The keys can be verified against [GitHub's published fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints).

If you need to connect to other SSH hosts (GitLab, Bitbucket, self-hosted), add their keys to `ssh/known_hosts` before building.

## Private plugins

The Dockerfile uses two build stages:

| Target | Contents | Used by |
|--------|----------|---------|
| `base` | System packages, Claude CLI, official plugins | `docker compose build` |
| `private` | Everything in `base` + private plugins via SSH | `BUILD_TARGET=private docker compose build` |

When `BASE_IMAGE` is set to a GHCR image (see `.env.example`), the `private` target pulls the pre-built public image instead of building the `base` stage locally.

To add private plugins, copy the example and add your plugin commands:

```bash
cp private/claude-plugins.sh.example private/claude-plugins.sh
```

Edit `private/claude-plugins.sh` to install your plugins:

```bash
#!/bin/bash
set -e
export SSH_AUTH_SOCK=$(ls /run/buildkit/ssh_agent.* 2>/dev/null | head -1)

claude plugin marketplace add git@github.com:your-org/your-plugins.git
claude plugin install your-plugin@your-plugins
```

The script runs during the `private` build stage with the host's SSH agent forwarded, allowing access to private repositories.

## Mount layout

| Container path | Host source | Access | Purpose |
|---------------|-------------|--------|---------|
| `/home/claude/<folder-name>` | Caller's `$PWD` | Read/Write | Project workspace |
| `/ssh-agent` | Host's `$SSH_AUTH_SOCK` | Read-only | SSH agent forwarding |

Both standalone and DevContainer modes use the same mount layout.

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Yes | OAuth token for Claude CLI authentication |
| `BASE_IMAGE` | No | Base image for `private` target: `base` (local, default) or GHCR image URL |
| `BUILD_TARGET` | No | Build target: `base` (default) or `private` (set inline, not in `.env`) |
| `GITHUB_TOKEN` | No | Token for GitHub CLI (`gh`) commands |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | No | Token for the GitHub MCP plugin |
| `GIT_USER_NAME` | No | Git committer name |
| `GIT_USER_EMAIL` | No | Git committer email |
| `SSH_PRIVATE_KEY_B64` | No | Base64-encoded SSH private key (fallback if no SSH agent) |

## CI/CD

### Build workflow

Runs on every push and pull request to `main`. Builds the `base` target with Docker Buildx and GitHub Actions cache.

### Publish workflow

Runs nightly (14:00 UTC) and on manual trigger. Builds the `base` target for `linux/amd64` and `linux/arm64`, and pushes to GHCR with the `latest` tag. This keeps the public image up to date with the latest Claude Code CLI version.

```bash
docker pull ghcr.io/matuscvengros/claude-sandbox:latest
```

### Release workflow

Triggered by version tags (`v*`). Builds multi-platform images (`linux/amd64`, `linux/arm64`) and pushes to GHCR:

```bash
docker pull ghcr.io/matuscvengros/claude-sandbox:<version>
```

A GitHub Release with auto-generated release notes is created alongside the image.

## Container defaults

The container ships with these Claude Code defaults (configured in `claude/settings.json`):

- **Model:** `opus`
- **Permissions:** `bypassPermissions` (autonomous mode) with `.env` files denied
- **Workspace trust:** Automatically granted at container start for the mounted working directory (`scripts/setup-claude-workdir-trust.sh`)
- **Onboarding:** Skipped (pre-configured in `claude/.claude.json`)
- **Auto-updates:** Enabled
