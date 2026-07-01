#!/usr/bin/env bash
# set-label.sh - Set a *stable* label for the current pane's window (and pane title).
#
# This is the recommended way (from inside the pane) to give agents/orchestrator a
# persistent name. Window names survive dynamic TUI title updates (Grok/Claude often
# overwrite pane titles with "Running:...", spinners, prompt text, " - grok").
#
# Window names are what list-agents.sh prefers for the FRIENDLY column and what
# appears in your tmux status bar ("8: voice-orchestrator").
#
# Usage (run this *from the pane you want to label*):
#   ./scripts/set-label.sh voice-orchestrator
#   ./scripts/set-label.sh agent-research
#   ./scripts/set-label.sh tf-drift-review
#
# After labeling, re-run list-agents.sh from the orchestrator. Targeting will work
# with the name, substring, or the window spec (e.g. "8:voice-orchestrator").
#
# The orchestrator can also tell a specialist: "run ./scripts/set-label.sh agent-foo
# in your pane so the conductor can find you reliably."

set -euo pipefail

# Support for remote hosts and distrobox (see common.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

NAME="${1:-}"

if [[ -z "$NAME" ]]; then
  echo "Usage: $0 <name>" >&2
  echo "  e.g.  ./scripts/set-label.sh agent-research" >&2
  echo "        ./scripts/set-label.sh voice-orchestrator" >&2
  exit 1
fi

# When executed from within the target pane, these affect exactly the right window + pane.
tmux select-pane -T "$NAME"
tmux rename-window "$NAME"

echo "Set pane title and renamed its window to '$NAME'."
echo "Window names are stable for list-agents.sh and targeting."
