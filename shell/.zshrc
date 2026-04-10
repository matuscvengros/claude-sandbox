# Claude Docker Sandbox Launcher
# Usage: cc [options] [-- extra args passed to claude/container]
#   cc                          Run Claude with persistent state
#   cc -is,  --isolated         Run Claude in ephemeral mode (no host state)
#   cc -s,   --shell            Drop into a bash shell instead of Claude
#   cc -v,   --volume <path>    Mount a host path into ~/  (read-write)
#   cc -rov, --read-only-volume Mount a host path into ~/  (read-only)
#   cc       --no-build         Skip the build step (use existing image)
cc() {
    local -a compose=(docker compose -f "$DOCKER_SANDBOX_DIR/docker-compose.yml")
    local project_name
    project_name="$(basename "$PWD")"

    local mode="persistent"
    local do_build=true
    local -a extra_vols=()
    local vol_path
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                echo "Usage: cc [options] [-- extra args passed to claude/container]"
                echo ""
                echo "Options:"
                echo "  -h,   --help                     Show this help message"
                echo "  -is,  --isolated                 Run Claude in ephemeral mode (no host state)"
                echo "  -s,   --shell                    Drop into a bash shell instead of Claude"
                echo "  -v,   --volume <path>            Mount a host path into ~/ (read-write)"
                echo "  -rov, --read-only-volume <path>  Mount a host path into ~/ (read-only)"
                echo "        --no-build                 Skip the build step (use existing image)"
                echo ""
                echo "Modes:"
                echo "  (default)   Run Claude with persistent state (~/.claude, ~/.config mounted)"
                echo "  isolated    Ephemeral container, no state persisted to host"
                echo "  shell       Shell access to the container (no Claude)"
                return 0
                ;;
            -is|--isolated) mode="isolated"; shift ;;
            -s|--shell)     mode="shell";    shift ;;
            --no-build)     do_build=false;  shift ;;
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
            --)             shift; break ;;
            *)              break ;;
        esac
    done

    # Build image (pulls latest base, rebuilds if needed)
    if $do_build; then
        PROJECT_NAME="$project_name" "${compose[@]}" build --pull || return 1
    fi

    case "$mode" in
        isolated)
            PROJECT_NAME="$project_name" "${compose[@]}" run --rm \
                "${extra_vols[@]}" \
                claude-sandbox claude --dangerously-skip-permissions "$@"
            ;;
        shell)
            PROJECT_NAME="$project_name" "${compose[@]}" run --rm \
                "${extra_vols[@]}" \
                claude-sandbox "$@"
            ;;
        persistent)
            PROJECT_NAME="$project_name" "${compose[@]}" run --rm \
                -v /Users/agents/.claude:/home/claude/.claude \
                -v /Users/agents/.claude.json:/home/claude/.claude.json \
                -v /Users/agents/.config:/home/claude/.config \
                "${extra_vols[@]}" \
                claude-sandbox \
                claude --dangerously-skip-permissions "$@"
            ;;
    esac

    # Clean up dangling claude-sandbox images
    docker image prune -f --filter "label=com.docker.compose.project=claude-sandbox" &>/dev/null
}
