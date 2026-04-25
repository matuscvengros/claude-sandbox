#!/bin/bash
# setup-codex-workdir-trust.sh - Adds the current working directory as a trusted
# project in Codex's config so the interactive trust prompt is skipped.
#
# Called from entrypoint.sh before launching an agent.

CODEX_CONFIG="$HOME/.codex/config.toml"
WORKSPACE="$(pwd)"

mkdir -p "$HOME/.codex"

if [ -d "$CODEX_CONFIG" ]; then
  echo "Error: $CODEX_CONFIG is a directory; expected a TOML file" >&2
  return 1 2>/dev/null || exit 1
fi

[ -f "$CODEX_CONFIG" ] || : > "$CODEX_CONFIG"

# TOML table keys use quoted strings, so escape the path before inserting it in
# [projects."<path>"].
PROJECT_KEY="$(printf '%s' "$WORKSPACE" | sed 's/\\/\\\\/g; s/"/\\"/g')"
PROJECT_TABLE="[projects.\"$PROJECT_KEY\"]"
TMP_CONFIG="${CODEX_CONFIG}.tmp"

# Remove any existing block for this project before appending the trusted block.
# This keeps repeated container starts idempotent and avoids duplicate TOML tables.
awk -v table="$PROJECT_TABLE" '
  function trim(s) {
    sub(/^[[:space:]]+/, "", s)
    sub(/[[:space:]]+$/, "", s)
    return s
  }
  function is_table_header(s) {
    return s ~ /^\[/ && s ~ /\]$/
  }
  trim($0) == table {
    in_target = 1
    next
  }
  in_target && is_table_header(trim($0)) {
    in_target = 0
  }
  !in_target {
    print
  }
' "$CODEX_CONFIG" > "$TMP_CONFIG"

{
  cat "$TMP_CONFIG"
  [ ! -s "$TMP_CONFIG" ] || printf '\n'
  printf '%s\n' "$PROJECT_TABLE"
  printf 'trust_level = "trusted"\n'
} > "${TMP_CONFIG}.new"

# Copy back instead of mv so bind-mounted files keep their mount identity.
cat "${TMP_CONFIG}.new" > "$CODEX_CONFIG"
rm -f "$TMP_CONFIG" "${TMP_CONFIG}.new"
