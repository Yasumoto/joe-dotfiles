#!/usr/bin/env bash
# conductor-status.sh - One-command "what is my orchestra doing right now?"
#
# UX polish for the conductor: combines roster state with live discovery.
# Run this frequently from the orchestrator pane.
#
# Usage:
#   ./scripts/conductor-status.sh [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

JSON=0
if [[ "${1:-}" == "--json" ]]; then
  JSON=1
fi

ROSTER_FILE="${ROSTER_FILE:-$HOME/.config/tmux-agent-orchestrator/roster.json}"

echo "=== Conductor Status ==="
echo "Time: $(date)"
echo

if [[ -f "$ROSTER_FILE" ]]; then
  echo "Roster ($ROSTER_FILE):"
  if [[ $JSON -eq 1 ]]; then
    cat "$ROSTER_FILE"
  else
    "${SCRIPT_DIR}/roster.sh" list 2>/dev/null || echo "(roster empty or error)"
  fi
else
  echo "No roster file yet (run roster.sh init or use flow_delegate.sh)"
fi

echo
echo "Live discovery (list-agents.sh):"
"${SCRIPT_DIR}/list-agents.sh" 2>/dev/null || echo "(could not list agents)"

echo
echo "Tip: Use flow_delegate.sh for high-level handoffs, roster.sh for state, list-agents.sh + capture-agent.sh for day-to-day awareness."
