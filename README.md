# Docker Sandbox for Agents

[![Build](https://github.com/matuscvengros/agent-sandbox/actions/workflows/build.yml/badge.svg)](https://github.com/matuscvengros/agent-sandbox/actions/workflows/build.yml)
[![Release](https://github.com/matuscvengros/agent-sandbox/actions/workflows/release.yml/badge.svg)](https://github.com/matuscvengros/agent-sandbox/actions/workflows/release.yml)
[![Nightly](https://github.com/matuscvengros/agent-sandbox/actions/workflows/nightly.yml/badge.svg)](https://github.com/matuscvengros/agent-sandbox/actions/workflows/nightly.yml)
[![Platform](https://img.shields.io/badge/platform-linux%2Famd64%20%7C%20linux%2Farm64-lightgrey?logo=linux)](https://ghcr.io/matuscvengros/agent-sandbox)

Docker container for running AI coding agents (Claude Code, OpenAI Codex, OpenCode, Pi) autonomously in an isolated sandbox. Based on `python:3.14-bookworm` with Node.js 24 grafted in. Built for macOS hosts using OrbStack where Docker Sandbox isn't available.

## Pre-installed tools

- Node.js 24 (LTS) + npm
- Python 3.14 + pip + uv, pytest, ruff, pyright, pint, engunits, scipy, numpy, pandas, matplotlib, requests, httpx, pydantic
- Rust stable via rustup — rustc, cargo, rustfmt, clippy
- C/C++ (gcc, g++, make, cmake, build-essential)
- Git, GitHub CLI (`gh`), curl, wget, ripgrep, fd-find, jq, openssh-client
- Starship prompt (Bracketed Segments preset)
- Firecrawl CLI (`firecrawl-cli`)
- AI coding agents (all installed as npm globals under the `agent` user):
  - **Claude Code** (`@anthropic-ai/claude-code`) — with official plugins, see [Plugins](#plugins)
  - **OpenAI Codex** (`@openai/codex`)
  - **SST opencode** (`opencode-ai`)
  - **Pi Coding Agent** (`@mariozechner/pi-coding-agent`) — minimal terminal coding harness supporting 15+ LLMs

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

You can get a token by running `claude setup-token` on your host machine.

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

### 5. Image source

The sandbox defaults to pulling the nightly-published image from GHCR — no build step required:

```bash
docker compose pull
```

That's it. `cc` will `docker compose run` against the pulled image on every invocation.

**Alternative: local build**

To build the image from the Dockerfile instead, use the build overlay:

```bash
docker compose -f docker-compose.yml -f docker-compose.build.yml build
```

Or let the `cc` helper do it via `cc -b` / `cc --build`. A local build tags the image as `agent-sandbox` and leaves the pulled GHCR image untouched.

To rebuild from scratch (no cache):

```bash
docker compose -f docker-compose.yml -f docker-compose.build.yml build --no-cache
```

Or via the helper: `cc -bf` / `cc --build-force`.

## Shell functions

Four launchers — one per AI agent — all share the same sandbox image, compose overlays, and flags:

| Command | Tool | Container command |
|---------|------|-------------------|
| `cc` | Claude Code        | `claude --dangerously-skip-permissions` |
| `cdx` | OpenAI Codex       | `codex --yolo` |
| `oc` | SST opencode       | `opencode --yolo` |
| `pidev` | Pi Coding Agent    | `pi` |

Internally all four delegate to a shared `_sandbox_run` function (in `shell/.zshrc` and `shell/.bashrc`). Each wrapper just sets the tool name + default args and calls the runner. In persistent mode (the default), the launcher pre-creates expected state files/directories, then mounts shared config (`~/.config/git`, `~/.config/gh`) plus every agent's state dir (`~/.claude`, `~/.claude.json`, `~/.codex`, `~/.config/opencode`, `~/.pi`), so session history, settings, and auth are unified with the host. The persistent overlay also masks Codex's bundled `browser-use` and `computer-use` plugin cache directories with tmpfs mounts.

### Setup (macOS with OrbStack)

```bash
# zsh (macOS default)
echo 'export DOCKER_SANDBOX_DIR="$HOME/path/to/agent-sandbox"' >> ~/.zshrc
cat shell/.zshrc >> ~/.zshrc
source ~/.zshrc

# bash (if you use bash)
echo 'export DOCKER_SANDBOX_DIR="$HOME/path/to/agent-sandbox"' >> ~/.bashrc
cat shell/.bashrc >> ~/.bashrc
source ~/.bashrc
```

### Usage

From any project directory:

```bash
cd ~/my-project

cc                         # run Claude Code, pulled GHCR image, persistent state
cc -- -p "build a REST API" # prompt mode, persistent state
cc -- --model sonnet       # override default model

cc -b                      # build image locally, then run
cc -bf                     # build locally with --no-cache, then run
cc --build -is             # build locally, isolated run

cc -is                     # interactive, isolated (no host state)
cc --isolated -- -p "task" # prompt mode, isolated

cc -v ~/data               # mount ~/data into container as ~/data (read-write)
cc -rov ~/config           # mount ~/config as read-only
cc -v ~/a -rov ~/b         # multiple extra volumes
cc -v ~/dir1/dir2/dir3     # mounts as ~/dir3 (basename only)

cc -sh                     # drop into a bash shell
cc --shell                 # same thing

cc -h                      # show help
```

`cdx`, `oc`, and `pidev` accept the exact same flags — every example above applies verbatim with the command name swapped:

```bash
cdx                         # Codex, pulled image, persistent state
oc                          # opencode, pulled image, persistent state
pidev                       # Pi Coding Agent, pulled image, persistent state

cdx -b -- --model gpt-5     # build locally, pass --model through to codex
oc -is                      # isolated opencode
pidev -sh                   # drop into a shell instead of Pi
```

### Flags (shared across all four launchers)

**`<agent>`** (default) uses the pulled GHCR image and mounts every agent's persistent state into the container, preserving conversation history, sessions, and auth across runs. `cc` adds `--dangerously-skip-permissions`, while `cdx` and `oc` add `--yolo`.

**`<agent> -b` / `<agent> --build`** builds the image locally from the Dockerfile before running. The local build is tagged `agent-sandbox` and doesn't affect the pulled GHCR image.

**`<agent> -bf` / `<agent> --build-force`** same as `--build` but passes `--no-cache` to Docker, bypassing the layer cache. Useful when a cached layer is masking a script change (e.g., `scripts/*`).

**`<agent> --isolated`** gives you a clean, disposable sandbox — the agent starts fresh with no memory of previous sessions and no access to host state.

**`<agent> --shell`** drops you into a bash shell inside the sandbox for manual inspection or setup. The agent is never launched.

**`<agent> -v <path>`** / **`<agent> --volume <path>`** mounts an additional host directory into the container at `/home/agent/<dirname>` (read-write). Repeatable for multiple volumes.

**`<agent> -rov <path>`** / **`<agent> --read-only-volume <path>`** same as `-v` but the mount is read-only. Useful for reference data or configs the agent shouldn't modify.

The current directory is automatically mounted into the container at the same absolute path (e.g., running from `/Users/you/my-project` mounts to `/Users/you/my-project`). This preserves Claude's path-derived session keys across host and container.

## Usage

### Standalone Compose

Without the shell function:

```bash
# Bash shell (the image default)
docker compose run --rm agent-sandbox

# Claude Code interactive
docker compose run --rm agent-sandbox claude --dangerously-skip-permissions

# Claude Code prompt mode
docker compose run --rm agent-sandbox claude --dangerously-skip-permissions -p "build a REST API for todos"

# Override Claude model
docker compose run --rm agent-sandbox claude --dangerously-skip-permissions --model sonnet -p "build a REST API"

# Other installed agents
docker compose run --rm agent-sandbox codex --yolo
docker compose run --rm agent-sandbox opencode --yolo
docker compose run --rm agent-sandbox pi
```

Use `--rm` to automatically remove the container after it exits. Add `-f docker-compose.persistent.yml` to the compose command when you want the same host state mounts that the shell launchers use by default.

## SSH & authentication

### SSH in the running container

SSH keys are only needed if you want Claude to perform git operations over SSH (push, pull, clone) inside the container. Two methods are supported, with agent forwarding preferred:

**1. SSH agent forwarding (recommended)**

If your host has an SSH agent running (`ssh-add -l` shows keys), the compose service forwards it into the container automatically using OrbStack's documented `/run/host-services/ssh-auth.sock` socket. This works for direct `docker compose run` usage and for the shell launchers.

```bash
# Verify your agent has keys loaded
ssh-add -l
```

The container uses `socat` to proxy the mounted SSH agent socket, with automatic retry logic on startup. No private key is copied into the image or container when agent forwarding is available.

**2. Base64-encoded key (fallback)**

If your host has no SSH agent (e.g., in CI), provide a base64-encoded private key in `.env`:

```bash
# Generate with:
base64 -i ~/.ssh/id_ed25519

# Then set in .env:
SSH_PRIVATE_KEY_B64=<base64-encoded-key>
```

The key is decoded at container startup, written to `~/.ssh/id_ed25519` with `600` permissions, and available for git operations. Agent forwarding takes priority if both are configured.

### Known hosts

The file `ssh/known_hosts` contains GitHub's published SSH host keys (RSA, ECDSA, Ed25519). These are copied into the container at build time to prevent interactive "Are you sure you want to continue connecting?" prompts. The keys can be verified against [GitHub's published fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints).

If you need to connect to other SSH hosts (GitLab, Bitbucket, self-hosted), add their keys to `ssh/known_hosts` before building.

## Extending with a private layer

This repo is a plain public build. To add private plugins, private apt packages, or custom configs, create a **separate** repository that uses the published GHCR image as its base:

```dockerfile
# your-private-repo/Dockerfile
FROM ghcr.io/matuscvengros/agent-sandbox:latest

# Add your private plugins, tools, config, etc.
RUN --mount=type=ssh \
    claude plugin marketplace add git@github.com:your-org/your-plugins.git \
    && claude plugin install your-plugin@your-plugins
```

That repo can tag its image as `agent-sandbox` locally (matching the name the `cc` helper expects) or give it any other tag and point `image:` in `docker-compose.yml` at it.

## Fresh builds

The Dockerfile intentionally uses floating current releases within the Python 3.14 and Node 24 base-image lines. Rust, Starship, Python packages, npm tools, and all AI-agent CLIs are installed fresh during uncached CI builds rather than pinned to exact versions.

## Mount layout

| Container path | Host source | Access | Purpose |
|---------------|-------------|--------|---------|
| `${PWD}` (same absolute path) | Caller's `$PWD` | Read/Write | Project workspace (1:1 mirror) |
| `/ssh-agent` | OrbStack `/run/host-services/ssh-auth.sock` | Read-only | SSH agent forwarding |
| `/home/agent/.config/git` | `$HOME/.config/git` | Read/Write | Git config (persistent mode only) |
| `/home/agent/.config/gh` | `$HOME/.config/gh` | Read/Write | GitHub CLI config (persistent mode only) |
| `/home/agent/.claude` | `$HOME/.claude` | Read/Write | Claude Code state (persistent mode only) |
| `/home/agent/.claude.json` | `$HOME/.claude.json` | Read/Write | Claude Code config (persistent mode only) |
| `/home/agent/.codex` | `$HOME/.codex` | Read/Write | Codex config + state (persistent mode only) |
| `/home/agent/.codex/plugins/cache/openai-bundled/browser-use` | tmpfs | Read/Write | Masks bundled Codex browser-use plugin cache (persistent mode only) |
| `/home/agent/.codex/plugins/cache/openai-bundled/computer-use` | tmpfs | Read/Write | Masks bundled Codex computer-use plugin cache (persistent mode only) |
| `/home/agent/.config/opencode` | `$HOME/.config/opencode` | Read/Write | opencode config (persistent mode only) |
| `/home/agent/.pi` | `$HOME/.pi` | Read/Write | Pi Coding Agent config + sessions (persistent mode only) |

The current directory is mounted into the container at the **same absolute path** it has on the host (1:1 mirror). This preserves Claude's per-project session keys (`~/.claude/projects/<path-encoded>`) across host and container and lets the startup trust scripts mark the exact host path as trusted for Claude and Codex. At startup, the entrypoint also creates a convenience symlink at `/home/agent/<workspace-basename>` when that path does not already exist.

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Yes | OAuth token for Claude CLI authentication |
| `GITHUB_TOKEN` | No | Token for GitHub CLI (`gh`) commands |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | No | Token for the GitHub MCP plugin |
| `GIT_USER_NAME` | No | Git committer name |
| `GIT_USER_EMAIL` | No | Git committer email |
| `SSH_PRIVATE_KEY_B64` | No | Base64-encoded SSH private key (fallback if no SSH agent) |

## CI/CD

### Build workflow

Runs on every push and pull request to `main`. Builds the image with Docker Buildx using fresh base-image pulls and no Docker layer cache.

### Nightly workflow

Runs nightly (14:00 UTC) and on manual trigger. Builds the image for `linux/amd64` and `linux/arm64` with fresh base pulls and no Docker layer cache, then pushes to GHCR with the `latest` tag.

```bash
docker pull ghcr.io/matuscvengros/agent-sandbox:latest
```

### Release workflow

Triggered by version tags (`v*`). Builds multi-platform images (`linux/amd64`, `linux/arm64`) and pushes to GHCR:

```bash
docker pull ghcr.io/matuscvengros/agent-sandbox:<version>
```

A GitHub Release with auto-generated release notes is created alongside the image.

## Container defaults

The container ships with these agent defaults:

- **Claude model:** `opus` (configured in `claude/settings.json`)
- **Claude effort:** `xhigh`
- **Claude permissions:** `bypassPermissions` (autonomous mode) with `.env` files denied
- **Workspace trust:** Automatically granted at container start for the mounted working directory (`scripts/setup-claude-workdir-trust.sh`, `scripts/setup-codex-workdir-trust.sh`)
- **Claude onboarding:** Skipped (pre-configured in `claude/.claude.json`)
- **Claude auto-updates:** Enabled
- **Claude voice:** Disabled
