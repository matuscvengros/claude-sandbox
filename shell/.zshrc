# Claude Docker Sandbox Launcher
# Usage: cc [options] [-- extra args passed to claude/container]
#   cc                          Run Claude, pulled image, persistent state
#   cc -b,   --build            Build the image locally instead of pulling
#   cc -bf,  --build-force      Build locally, bypassing the layer cache
#   cc -is,  --isolated         Run Claude in ephemeral mode (no host state)
#   cc -sh,   --shell           Drop into a bash shell instead of Claude
#   cc -v,   --volume <path>    Mount a host path into ~/  (read-write)
#   cc -rov, --read-only-volume Mount a host path into ~/  (read-only)
cc() {
    local -a compose=(docker compose -f "$DOCKER_SANDBOX_DIR/docker-compose.yml")
    local local_build=false
    local build_no_cache=false
    local mode="persistent"
    local -a extra_vols=()
    local vol_path
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                echo "Usage: cc [options] [-- extra args passed to claude/container]"
                echo ""
                echo "Options:"
                echo "  -h,   --help                     Show this help message"
                echo "  -b,   --build                    Build the image locally instead of pulling from GHCR"
                echo "  -bf,  --build-force              Build locally, bypassing the layer cache (--no-cache)"
                echo "  -is,  --isolated                 Run Claude in ephemeral mode (no host state)"
                echo "  -sh,   --shell                   Drop into a bash shell instead of Claude"
                echo "  -v,   --volume <path>            Mount a host path into ~/ (read-write)"
                echo "  -rov, --read-only-volume <path>  Mount a host path into ~/ (read-only)"
                echo ""
                echo "Image source:"
                echo "  (default)       Pulled from ghcr.io/matuscvengros/claude-sandbox:latest"
                echo "  --build         Built locally from the Dockerfile"
                echo "  --build-force   Built locally with --no-cache"
                echo ""
                echo "Modes:"
                echo "  (default)   Persistent state — mounts ~/.claude, ~/.claude.json, ~/.config"
                echo "  isolated    Ephemeral container, no state persisted to host"
                echo "  shell       Shell access to the container (no Claude)"
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
                mode="isolated";
                shift ;;
            -sh|--shell)
                mode="shell";
                shift ;;
            -v|--volume)
                shift
                if [[ -z "$1" ]]; then echo "Error: -v/--volume requires a path argument" >&2; return 1; fi
                vol_path="$(realpath "$1" 2>/dev/null)" || { echo "Error: path not found: $1" >&2; return 1; }
                extra_vols+=(-v "$vol_path:/home/claude/$(basename "$vol_path")")
                shift ;;
            -rov|--read-only-volume)
                shift
                if [[ -z "$1" ]]; then echo "Error: -rov/--read-only-volume requires a path argument" >&2; return 1; fi
                vol_path="$(realpath "$1" 2>/dev/null)" || { echo "Error: path not found: $1" >&2; return 1; }
                extra_vols+=(-v "$vol_path:/home/claude/$(basename "$vol_path"):ro")
                shift ;;
            --)
                shift;
                break ;;
            *)
                break ;;
        esac
    done

    if $local_build; then
        local -a build_args=(build)
        $build_no_cache && build_args+=(--no-cache)
        "${compose[@]}" "${build_args[@]}" || return 1
    fi

    case "$mode" in
        isolated)
            "${compose[@]}" run --rm \
                "${extra_vols[@]}" \
                claude-sandbox claude --dangerously-skip-permissions "$@"
            ;;
        shell)
            "${compose[@]}" run --rm \
                "${extra_vols[@]}" \
                claude-sandbox "$@"
            ;;
        persistent)
            compose+=(-f "$DOCKER_SANDBOX_DIR/docker-compose.persistent.yml")
            "${compose[@]}" run --rm \
                "${extra_vols[@]}" \
                claude-sandbox \
                claude --dangerously-skip-permissions "$@"
            ;;
    esac
}
