# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker-based sandbox for running AI coding agents (Claude Code, OpenAI Codex, OpenCode, Pi) autonomously in isolation. It produces a container image based on `python:3.14-bookworm` (Debian Bookworm) with Node.js 24 grafted in, plus all four AI-agent CLIs (Claude Code with 24+ official plugins) and common dev tools pre-installed. The primary audience is macOS hosts using OrbStack where Docker Sandbox isn't available.

## Image sources

The image can be obtained two ways — these are the only two:

1. **Pull the published image from GHCR** (default, nightly-built): `docker compose pull` — uses `docker-compose.yml` alone, which references `ghcr.io/matuscvengros/agent-sandbox:latest`.
2. **Build locally from the Dockerfile**: `docker compose -f docker-compose.yml -f docker-compose.build.yml build`. The build overlay swaps the pulled image reference for a local build tagged `agent-sandbox`.

The `cc` helper's `-b/--build` flag adds the build overlay and runs the build before the run. Without `-b`, `cc` uses the pulled GHCR image.

## Run commands

```bash
# Bash shell (standalone, pulled image; this is the image default)
docker compose run --rm agent-sandbox

# Claude Code interactive
docker compose run --rm agent-sandbox claude --dangerously-skip-permissions

# Claude Code prompt mode
docker compose run --rm agent-sandbox claude --dangerously-skip-permissions -p "your prompt here"

# Override Claude model
docker compose run --rm agent-sandbox claude --dangerously-skip-permissions --model sonnet -p "your prompt"
```

The `cc` shell function (defined in `shell/.zshrc` and `shell/.bashrc`) wraps these for daily use from any project directory. It supports `-b`/`--build`, `--isolated`, `--shell`, `--volume`/`--read-only-volume` flags.

## Architecture

```
Host (macOS + OrbStack)               Container (Linux)
┌──────────────┐                     ┌──────────────────────────┐
│ shell/.zshrc │──cc command───>  │ /entrypoint.sh           │
│ (cc/cdx/oc/ │                     │   ├─ setup-credentials   │
│  pidev funcs)│   docker compose    │   ├─ setup-claude-trust  │
│ $PWD ────────│── volume mount ──>  │   ├─ setup-codex-trust   │
│              │                     │   └─ agent CLI / bash    │
│ OrbStack SSH │── forwarding ───>   │ /ssh-agent               │
│ $HOME/.claude│── persistent ───>   │ /home/agent/.claude      │
│ $HOME/.codex │── persistent ───>   │ /home/agent/.codex       │
└──────────────┘                     │ ${PWD} (1:1 mirror)      │
                                     └──────────────────────────┘
```

### Directory layout

- `claude/` — Build-time Claude config (`.claude.json`, `settings.json`)
- `.claude/` — Runtime/local config overrides
- `scripts/` — Container startup hooks (entrypoint, credentials, trust)
- `shell/` — Host-side launcher functions (`cc`, `cdx`, `oc`, `pidev`) for bash/zsh, sharing a common `_sandbox_run` engine
- `ssh/` — GitHub SSH known_hosts
- `.github/workflows/` — CI/CD (build, nightly publish to GHCR, releases)

### Dockerfile

Multi-stage build: a floating `node:24-bookworm` stage (`node-src`) supplies the Node binary and its bundled `node_modules` (npm, npx, corepack), which are copied into the floating `python:3.14-bookworm` stage. Python is the base because it's the harder language to graft — it needs pip, shared libs, the stdlib, and headers; Node only needs the binary plus a symlink set. The final stage adds system packages, latest stable Rust, fresh Python/npm tools, fresh AI-agent CLIs (Claude Code, OpenAI Codex, SST opencode, Pi Coding Agent — all installed as npm globals under the `agent` user via `NPM_CONFIG_PREFIX=/home/agent/.npm-global`, so no sudo), official Claude marketplace plugins, and entrypoint scripts. A top-level `LABEL org.opencontainers.image.title="agent-sandbox"` tags the image for the launcher prune filter (shared across `cc`/`cdx`/`oc`/`pidev`) regardless of builder (local or CI). This is the image published nightly to GHCR (`ghcr.io/matuscvengros/agent-sandbox:latest`).

**Entrypoint flow** (`scripts/entrypoint.sh`):
1. Sources `scripts/setup-credentials.sh` — sets up SSH (agent forwarding via socat proxy, or base64 key fallback) and git identity from env vars.
2. Sources `scripts/setup-claude-workdir-trust.sh` — injects the current working directory as a trusted project in `~/.claude.json` using jq, so Claude skips the interactive trust prompt. It preserves existing per-project fields such as `allowedTools`.
3. Sources `scripts/setup-codex-workdir-trust.sh` — injects the current working directory as a trusted project in `~/.codex/config.toml`, so Codex skips the interactive trust prompt.
4. Creates a convenience symlink at `/home/agent/<workspace-basename>` when the workspace is not `/home/agent` and no path already exists at the link target.
5. Runs CMD (defaults to `bash`).

**Container defaults** (`claude/settings.json`):
- Model: `opus`
- Effort: `xhigh`
- Permissions: `bypassPermissions` with `.env` files denied
- Voice: disabled
- Onboarding skipped (`claude/.claude.json`)
- Workspace trust is granted at container start for both Claude (`~/.claude.json`) and Codex (`~/.codex/config.toml`).

**Compose files:**
- `docker-compose.yml` — references the pulled GHCR image; defines `.env` loading, the project mount (`${PWD}:${PWD}`), and OrbStack SSH agent forwarding. This is the only file needed for the default pull-and-run flow.
- `docker-compose.build.yml` — overlay that replaces `image:` with a local build tag and adds `build.context`. Used via `-f docker-compose.yml -f docker-compose.build.yml` (or the `cc -b` flag).
- `docker-compose.persistent.yml` — overlay that adds host state bind mounts grouped in descending scope: shared config (`~/.config/git`, `~/.config/gh`), then per-agent state (Claude Code: `~/.claude`, `~/.claude.json`; Codex: `~/.codex`; opencode: `~/.config/opencode`; Pi: `~/.pi`). It also masks Codex's bundled `browser-use` and `computer-use` plugin cache directories with tmpfs mounts. Applied by every launcher (`cc`/`cdx`/`oc`/`pidev`) in persistent (default) mode; not used by `--isolated` or `--shell`.

**Shell functions** (`shell/.zshrc`, `shell/.bashrc`):
- Four launchers — one per AI agent — share a single engine. Each wrapper (`cc`, `cdx`, `oc`, `pidev`) sets one dynamically-scoped local array (`$agent_command` — the in-container CLI command + default flags) and calls `_sandbox_run`, which does arg parsing, image pull/build, container run, persistent state preparation, exit-code preserving cleanup, and dangling-image prune. `_sandbox_help` prints a static usage message identical for all four launchers, using `<agent>` as the placeholder.
- Tool commands baked into the wrappers: `cc → claude --dangerously-skip-permissions`, `cdx → codex --yolo`, `oc → opencode --yolo`, `pidev → pi`.
- All four accept the same options: `-b/--build`, `-bf/--build-force`, `-is/--isolated`, `-sh/--shell`, `-v/--volume`, `-rov/--read-only-volume`, `-h/--help`.
- Persistent mode (default): creates expected host state paths, layers on `docker-compose.persistent.yml`, and bind-mounts shared config + every agent's state dir, so sessions and auth unify with the host across all four tools.
- `--isolated`: no state mounts; only image-baked config is visible.
- `--shell`: drops into a bash shell, no agent launch.
- `-b/--build`: runs `docker compose build` with the build overlay, then runs.
- The project workspace is mounted at the same absolute path as the host (`$PWD:$PWD` 1:1 mirror), so Claude Code's per-project session keys (`~/.claude/projects/<path-encoded>`) match between host and container. The other agents mount their project-local config via the workspace mount (`opencode.json`, `.opencode/`, `.pi/` in the project root all appear live in the container).
- Direct `docker compose run` defaults to bash because the Dockerfile sets `CMD ["bash"]`. To launch an agent without the shell functions, pass the agent command explicitly after the service name.

**CI/CD** (`.github/workflows/`):
- `build.yml`: runs on push/PR to main, builds the image with Buildx, `pull: true`, and `no-cache: true`.
- `nightly.yml`: nightly at 14:00 UTC + manual trigger, builds multi-arch (`amd64`/`arm64`) with fresh base pulls and no Docker layer cache, then pushes `latest` to GHCR.
- `release.yml`: triggered by `v*` tags, builds multi-arch with fresh base pulls and no Docker layer cache, pushes semver tags to GHCR, creates GitHub Release with auto-generated notes.

## Key files

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage image build (Python 3.14 base + Node 24 graft + Rust + 4 AI-agent CLIs + Claude plugins) |
| `docker-compose.yml` | Service definition with env, workspace volume, and OrbStack SSH agent forwarding; references pulled GHCR image |
| `docker-compose.build.yml` | Overlay that swaps pulled image for a local build |
| `docker-compose.persistent.yml` | Overlay that adds host state mounts and Codex plugin-cache tmpfs masks for persistent mode |
| `scripts/entrypoint.sh` | Container startup orchestration |
| `scripts/setup-credentials.sh` | SSH agent proxy + git identity setup |
| `scripts/setup-claude-workdir-trust.sh` | Auto-trusts mounted workspace in Claude config |
| `scripts/setup-codex-workdir-trust.sh` | Auto-trusts mounted workspace in Codex config |
| `claude/settings.json` | Claude Code runtime settings (model, permissions) |
| `claude/.claude.json` | Claude Code state (onboarding, updates) |
| `shell/.zshrc` / `shell/.bashrc` | Host shell launchers (`cc`/`cdx`/`oc`/`pidev`) built on a shared `_sandbox_run` engine |
| `.env` | Runtime secrets (gitignored, created from `.env.example`) |

## Environment variables

Required for fresh Claude authentication: `CLAUDE_CODE_OAUTH_TOKEN` (set in `.env`).

Optional: `GITHUB_TOKEN`, `GITHUB_PERSONAL_ACCESS_TOKEN`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, `SSH_PRIVATE_KEY_B64`.

## Documentation

- `README.md` is the primary user-facing documentation. It must be kept in sync with any changes to the Dockerfile, compose files, scripts, shell functions, environment variables, CI/CD workflows, or plugin list. When making changes to the project, update `README.md` to reflect them.

## Conventions

- The container runs as user `agent` (UID 1000), not root. Root access via passwordless sudo.
- The agent user's home is `/home/agent` — hardcoded in the Dockerfile. The launchers (`cc`/`cdx`/`oc`/`pidev`) mount shared host config (`~/.config/git`, `~/.config/gh`) and every agent's state dir (`~/.claude`, `~/.claude.json`, `~/.codex`, `~/.config/opencode`, `~/.pi`) under `/home/agent/` in persistent mode (via `docker-compose.persistent.yml`).
- The host project directory is mounted at the **same absolute path** in the container (e.g., `/Users/you/code/app` → `/Users/you/code/app`). Docker creates intermediate directories automatically. This 1:1 mirror preserves Claude's path-derived session keys for cross-environment session sharing.
- The entrypoint creates a convenience symlink from `/home/agent/<workspace-basename>` to the mounted workspace when that link path is free. Do not rely on it for identity-sensitive paths; the 1:1 absolute mount is the canonical workspace path.
- Persistent mode currently tmpfs-mounts `/home/agent/.codex/plugins/cache/openai-bundled/browser-use` and `/home/agent/.codex/plugins/cache/openai-bundled/computer-use` over the host-mounted Codex state.
- SSH agent forwarding is preferred over key injection. `docker-compose.yml` mounts OrbStack's documented `/run/host-services/ssh-auth.sock` socket to `/ssh-agent` and sets `SSH_AUTH_SOCK=/ssh-agent`, so direct compose usage and shell launchers behave the same way. The entrypoint proxies the mounted socket via socat to work around permission issues.
- The `.env` file is gitignored and denied from Claude's read permissions in `claude/settings.json`.
- Private customization (personal plugins, extra apt packages, custom configs) belongs in a separate repo that `FROM`s the published GHCR image. See `README.md` → "Extending with a private layer".
- `npm install -g …` under `USER agent` writes to `/home/agent/.npm-global/` (via `NPM_CONFIG_PREFIX`), not `/usr/local/lib/node_modules`. `~/.npm-global/bin` is on PATH. This is how the four AI-agent CLIs install without sudo. Root-time npm installs earlier in the Dockerfile (pre-`USER agent`) still use the default `/usr/local` prefix.
