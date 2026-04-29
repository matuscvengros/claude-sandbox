# Agent Sandbox Launchers
#
# Launch one of four AI-agent CLIs inside the agent-sandbox container:
#   cc      Claude Code        (claude --dangerously-skip-permissions)
#   cx      OpenAI Codex       (codex --yolo)
#   oc      OpenCode           (opencode)
#   pidev   Pi Coding Agent    (pi)
#
# All four wrappers delegate to `_sandbox_run`. See `<agent> -h` for usage.

# ---------------------------------------------------------------------------
# Shared help — static, identical for all four launchers.
# ---------------------------------------------------------------------------
_sandbox_help() {
    cat <<'EOF'
Launches an AI-agent CLI inside the agent-sandbox Docker container.
Available agents: cc (Claude Code), cx (Codex), oc (OpenCode), pidev (Pi
Coding Agent). All accept the same flags.

Usage: <agent> [options] [-- extra args passed to the agent]

Options:
  -h,   --help                     Show this help message
  -b,   --build                    Build the image locally instead of pulling from GHCR
  -bf,  --build-force              Build locally, bypassing the layer cache (--no-cache)
  -is,  --isolated                 Ephemeral mode (no host state mounted)
  -sh,  --shell                    Drop into a bash shell instead of launching the agent
  -v,   --volume <path>            Mount a host path into ~/ (read-write)
  -rov, --read-only-volume <path>  Mount a host path into ~/ (read-only)

Image source:
  (default)       Pulled from ghcr.io/matuscvengros/agent-sandbox:latest
  --build         Built locally from the Dockerfile
  --build-force   Built locally with --no-cache

Modes:
  (default)   Persistent — mounts shared config (~/.config/git, ~/.config/gh)
              and every AI-agent state dir (~/.claude, ~/.claude.json,
              ~/.codex, ~/.config/opencode, ~/.pi), creating missing state
              paths first
  isolated    Ephemeral container, no state persisted to host
  shell       Shell access to the container (no agent launched)
EOF
}

# ---------------------------------------------------------------------------
# Persistent state setup — Docker bind-mounts missing file sources as
# directories, so create expected file mounts before Compose runs.
# ---------------------------------------------------------------------------
_sandbox_prepare_persistent_state() {
    mkdir -p \
        "$HOME/.config/git" \
        "$HOME/.config/gh" \
        "$HOME/.claude" \
        "$HOME/.codex" \
        "$HOME/.config/opencode" \
        "$HOME/.pi" || return 1

    if [[ -d "$HOME/.claude.json" ]]; then
        echo "Error: $HOME/.claude.json is a directory; expected a JSON file" >&2
        return 1
    fi

    if [[ ! -e "$HOME/.claude.json" ]]; then
        printf '{}\n' > "$HOME/.claude.json" || return 1
    fi
}

# ---------------------------------------------------------------------------
# Shared runner — parses flags, pulls or builds the image, runs the
# container with the wrapper's tool command, and prunes dangling images.
#
# Each wrapper sets (via `local`):
#   $agent_command  Array: the command + default args to run in the container
# ---------------------------------------------------------------------------
_sandbox_run() {
    local -a compose=(docker compose -f "$DOCKER_SANDBOX_DIR/docker-compose.yml")
    local local_build=false
    local build_no_cache=false
    local mode="persistent"
    local -a extra_vols=()
    local vol_path
    local run_status=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                _sandbox_help
                return 0
                ;;
            -b|--build)
                local_build=true
                compose+=(-f "$DOCKER_SANDBOX_DIR/docker-compose.build.yml")
                shift ;;
            -bf|--build-force)
                local_build=true
                build_no_cache=true
                compose+=(-f "$DOCKER_SANDBOX_DIR/docker-compose.build.yml")
                shift ;;
            -is|--isolated)
                mode="isolated"
                shift ;;
            -sh|--shell)
                mode="shell"
                shift ;;
            -v|--volume)
                shift
                if [[ -z "$1" ]]; then echo "Error: -v/--volume requires a path argument" >&2; return 1; fi
                vol_path="$(realpath "$1" 2>/dev/null)" || { echo "Error: path not found: $1" >&2; return 1; }
                extra_vols+=(-v "$vol_path:/home/agent/$(basename "$vol_path")")
                shift ;;
            -rov|--read-only-volume)
                shift
                if [[ -z "$1" ]]; then echo "Error: -rov/--read-only-volume requires a path argument" >&2; return 1; fi
                vol_path="$(realpath "$1" 2>/dev/null)" || { echo "Error: path not found: $1" >&2; return 1; }
                extra_vols+=(-v "$vol_path:/home/agent/$(basename "$vol_path"):ro")
                shift ;;
            --)
                shift
                break ;;
            *)
                break ;;
        esac
    done

    if $local_build; then
        local -a build_args=(build)
        $build_no_cache && build_args+=(--no-cache)
        "${compose[@]}" "${build_args[@]}" || return 1
    else
        "${compose[@]}" pull agent-sandbox || echo "agent-sandbox: image pull failed, using local copy" >&2
    fi

    case "$mode" in
        isolated)
            "${compose[@]}" run --rm \
                "${extra_vols[@]}" \
                agent-sandbox "${agent_command[@]}" "$@"
            run_status=$?
            ;;
        shell)
            _sandbox_prepare_persistent_state || return 1
            compose+=(-f "$DOCKER_SANDBOX_DIR/docker-compose.persistent.yml")
            "${compose[@]}" run --rm \
                "${extra_vols[@]}" \
                agent-sandbox "$@"
            run_status=$?
            ;;
        persistent)
            _sandbox_prepare_persistent_state || return 1
            compose+=(-f "$DOCKER_SANDBOX_DIR/docker-compose.persistent.yml")
            "${compose[@]}" run --rm \
                "${extra_vols[@]}" \
                agent-sandbox \
                "${agent_command[@]}" "$@"
            run_status=$?
            ;;
    esac

    # Clean up dangling agent-sandbox images
    docker image prune -f --filter "label=org.opencontainers.image.title=agent-sandbox" &>/dev/null || true
    return "$run_status"
}

# ---------------------------------------------------------------------------
# Wrappers — one per AI-agent CLI.
# ---------------------------------------------------------------------------

# cc — Claude Code
cc() {
    local -a agent_command=(claude --dangerously-skip-permissions)
    _sandbox_run "$@"
}

# cx — OpenAI Codex
cx() {
    local -a agent_command=(codex --yolo)
    _sandbox_run "$@"
}

# oc — OpenCode
oc() {
    local -a agent_command=(opencode)
    _sandbox_run "$@"
}

# pidev — Pi Coding Agent
pidev() {
    local -a agent_command=(pi)
    _sandbox_run "$@"
}
