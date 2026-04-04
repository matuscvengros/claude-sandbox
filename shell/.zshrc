# Claude Docker Sandbox launcher
# Usage: cc [options] [-- extra args passed to claude/container]
#   cc                  Run Claude with persistent state
#   cc -is, --isolated  Run Claude in ephemeral mode (no host state)
#   cc -b, --bash       Drop into a bash shell instead of Claude
#   cc --no-build       Skip the build step (use existing image)
cc() {
    local -a compose=(docker compose -f "$DOCKER_SANDBOX_DIR/docker-compose.yml")
    local project_name
    project_name="$(basename "$PWD")"

    local mode="persistent"
    local do_build=true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                echo "Usage: cc [options] [-- extra args passed to claude/container]"
                echo ""
                echo "Options:"
                echo "  -h,  --help      Show this help message"
                echo "  -is, --isolated  Run Claude in ephemeral mode (no host state)"
                echo "  -b,  --bash      Drop into a bash shell instead of Claude"
                echo "  --no-build       Skip the build step (use existing image)"
                echo ""
                echo "Modes:"
                echo "  (default)   Run Claude with persistent state (~/.claude, ~/.config mounted)"
                echo "  isolated    Ephemeral container, no state persisted to host"
                echo "  bash        Shell access to the container (no Claude)"
                return 0
                ;;
            -is|--isolated) mode="isolated"; shift ;;
            -b|--bash)      mode="bash";     shift ;;
            --no-build)     do_build=false;  shift ;;
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
            PROJECT_NAME="$project_name" "${compose[@]}" run --rm claude-sandbox claude --dangerously-skip-permissions "$@"
            ;;
        bash)
            PROJECT_NAME="$project_name" "${compose[@]}" run --rm claude-sandbox "$@"
            ;;
        persistent)
            PROJECT_NAME="$project_name" "${compose[@]}" run --rm \
                -v /Users/agents/.claude:/home/claude/.claude \
                -v /Users/agents/.claude.json:/home/claude/.claude.json \
                -v /Users/agents/.config:/home/claude/.config \
                claude-sandbox \
                claude --dangerously-skip-permissions "$@"
            ;;
    esac
}
