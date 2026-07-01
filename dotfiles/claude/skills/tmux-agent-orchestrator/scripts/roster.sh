#!/usr/bin/env bash
# roster.sh - Persistent state for the tmux-agent-orchestrator (conductor skill).
#
# Stores a simple JSON roster of known agents under:
#   $ROSTER_FILE (default: ~/.config/tmux-agent-orchestrator/roster.json)
#
# This gives the orchestrator (and specialists) a shared, queryable view of
# who is doing what, across restarts, tmux resurrect, and multiple sessions.
#
# Usage:
#   ./scripts/roster.sh init
#   ./scripts/roster.sh list [--json]
#   ./scripts/roster.sh get <name>
#   ./scripts/roster.sh set <name> '<json-fragment-or-full>'
#   ./scripts/roster.sh update <name> <key> <value>
#   ./scripts/roster.sh remove <name>
#   ./scripts/roster.sh mark <name> done|in-progress|blocked [summary]
#   ./scripts/roster.sh clear
#
# The roster is intentionally lightweight. Scripts like list-agents.sh,
# launch-agent.sh, and flow_delegate.sh can read/write it.
#
# Environment:
#   ROSTER_FILE   Override default location
#   ROSTER_DIR    Directory (default ~/.config/tmux-agent-orchestrator)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

ROSTER_DIR="${ROSTER_DIR:-$HOME/.config/tmux-agent-orchestrator}"
ROSTER_FILE="${ROSTER_FILE:-$ROSTER_DIR/roster.json}"

mkdir -p "$ROSTER_DIR"

# Ensure a valid JSON object (or array) file exists
ensure_roster() {
  if [[ ! -f "$ROSTER_FILE" ]]; then
    echo '{}' > "$ROSTER_FILE"
  fi
  # Make sure it's valid JSON
  if ! jq empty "$ROSTER_FILE" >/dev/null 2>&1; then
    echo '{}' > "$ROSTER_FILE"
  fi
}

cmd="${1:-list}"
shift || true

ensure_roster

case "$cmd" in
  init)
    echo '{}' > "$ROSTER_FILE"
    echo "Roster initialized at $ROSTER_FILE"
    ;;

  list)
    if [[ "${1:-}" == "--json" ]]; then
      cat "$ROSTER_FILE"
    else
      echo "Current roster ($ROSTER_FILE):"
      jq -r '
        to_entries[] |
        "\(.key): role=\(.value.role // "unknown") status=\(.value.status // "unknown") task=\(.value.task // "-") pane=\(.value.pane // "-")"
      ' "$ROSTER_FILE" | sort || echo "(empty)"
    fi
    ;;

  get)
    name="${1:-}"
    if [[ -z "$name" ]]; then
      echo "Usage: roster.sh get <name>" >&2
      exit 1
    fi
    jq --arg n "$name" '.[$n] // empty' "$ROSTER_FILE"
    ;;

  set)
    name="${1:-}"
    fragment="${2:-}"
    if [[ -z "$name" || -z "$fragment" ]]; then
      echo "Usage: roster.sh set <name> '<json-fragment>'" >&2
      exit 1
    fi
    # Merge fragment into the entry for $name
    jq --arg n "$name" --argjson frag "$fragment" '
      .[$n] = (.[$n] // {}) + $frag
    ' "$ROSTER_FILE" > "$ROSTER_FILE.tmp" && mv "$ROSTER_FILE.tmp" "$ROSTER_FILE"
    echo "Updated roster entry for $name"
    ;;

  update)
    name="${1:-}"
    key="${2:-}"
    value="${3:-}"
    if [[ -z "$name" || -z "$key" ]]; then
      echo "Usage: roster.sh update <name> <key> <value>" >&2
      exit 1
    fi
    jq --arg n "$name" --arg k "$key" --arg v "$value" '
      .[$n] = (.[$n] // {}) | .[$n][$k] = $v
    ' "$ROSTER_FILE" > "$ROSTER_FILE.tmp" && mv "$ROSTER_FILE.tmp" "$ROSTER_FILE"
    echo "Updated $name.$key"
    ;;

  mark)
    name="${1:-}"
    status="${2:-}"
    summary="${3:-}"
    if [[ -z "$name" || -z "$status" ]]; then
      echo "Usage: roster.sh mark <name> <done|in-progress|blocked> [summary]" >&2
      exit 1
    fi
    jq --arg n "$name" --arg s "$status" --arg sum "$summary" '
      .[$n] = (.[$n] // {}) |
      .[$n].status = $s |
      if $sum != "" then .[$n].last_summary = $sum else . end |
      .[$n].updated = (now | strftime("%Y-%m-%d %H:%M:%S"))
    ' "$ROSTER_FILE" > "$ROSTER_FILE.tmp" && mv "$ROSTER_FILE.tmp" "$ROSTER_FILE"
    echo "Marked $name as $status"
    ;;

  remove)
    name="${1:-}"
    if [[ -z "$name" ]]; then
      echo "Usage: roster.sh remove <name>" >&2
      exit 1
    fi
    jq --arg n "$name" 'del(.[$n])' "$ROSTER_FILE" > "$ROSTER_FILE.tmp" && mv "$ROSTER_FILE.tmp" "$ROSTER_FILE"
    echo "Removed $name from roster"
    ;;

  clear)
    echo '{}' > "$ROSTER_FILE"
    echo "Roster cleared"
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    echo "Commands: init list get set update mark remove clear"
    exit 1
    ;;
esac
