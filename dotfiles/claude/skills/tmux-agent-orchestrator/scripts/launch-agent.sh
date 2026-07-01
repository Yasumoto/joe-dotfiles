#!/usr/bin/env bash
# launch-agent.sh - Create a new pane (or window) and launch an AI agent TUI in it.
# Usage: launch-agent.sh <friendly-name> [role-hint] [start-dir] [--window|--split]
#
# - friendly-name becomes the pane/window title (e.g. agent-research)
# - role-hint is sent as the first message after launch (optional but recommended)
# - Defaults to splitting a new pane vertically in the current window.
# - Supports --window to create a brand new window instead.
# - Tries to detect a good launch command (claude, grok, hermes) or falls back.

set -euo pipefail

# Support for remote hosts and distrobox (see common.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

NAME="${1:-}"
ROLE="${2:-}"
DIR="${3:-$(pwd)}"
MODE="split"   # split or window

shift 3 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --window) MODE="window"; shift ;;
    --split)  MODE="split"; shift ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "Usage: $0 <friendly-name> [\"role description\"] [start-dir] [--window|--split]" >&2
  exit 1
fi

# Choose launch command
LAUNCH_CMD=""
if command -v claude >/dev/null 2>&1; then
  LAUNCH_CMD="claude --dangerously-skip-permissions"
elif command -v grok >/dev/null 2>&1; then
  LAUNCH_CMD="grok"
elif command -v hermes >/dev/null 2>&1; then
  LAUNCH_CMD="hermes"
else
  echo "Warning: no claude/grok/hermes in PATH. You will need to start the agent manually." >&2
  LAUNCH_CMD="bash -i"
fi

# Create the pane/window
CURRENT_SESSION=$(tmux display-message -p '#{session_name}' 2>/dev/null || echo "")

if [[ "$MODE" == "window" ]]; then
  tmux new-window -t "$CURRENT_SESSION" -n "$NAME" -c "$DIR"
  TARGET="$CURRENT_SESSION:$NAME"
else
  # Split, prefer vertical for "team on the side"
  tmux split-window -h -t "$CURRENT_SESSION" -c "$DIR"
  # The new pane is now the active one in the current window
  tmux select-pane -T "$NAME"
  TARGET=$(tmux display-message -p '#{pane_id}')
fi

# Give the shell a moment, then launch the agent
# Use double quotes + basic escape for DIR (safer than single quotes if DIR contains ')
sleep 0.4
escaped_dir=${DIR//\"/\\\"}
tmux send-keys -t "$TARGET" "cd \"${escaped_dir}\" && $LAUNCH_CMD" C-m

# Set labels for discoverability. For new windows we rename the window (stable).
# For splits we at least set the pane title; the new agent can later run
# ./scripts/set-label.sh $NAME inside its pane if it wants a dedicated window name too.
tmux select-pane -t "$TARGET" -T "$NAME"
if [[ "$MODE" == "window" ]]; then
  tmux rename-window -t "$TARGET" "$NAME"
fi

echo "Launched in $TARGET (name=$NAME, dir=$DIR)"
echo "Target for other scripts: $NAME (preferred, stable via window name), $TARGET, or the pane id"
echo "If this is a split pane and you want a stable window name for it, have the agent run:"
echo "  ./scripts/set-label.sh $NAME"

# If role hint provided, send it after a short delay (give the TUI time to start).
# Also append a short note about stable labeling so the new specialist can make itself
# easy for the orchestrator to find even with dynamic TUI titles.
if [[ -n "$ROLE" ]]; then
  sleep 2.5
  LABEL_NOTE=""
  if [[ "$MODE" != "window" ]]; then
    LABEL_NOTE=$'\n\n(After you start, if you want a dedicated stable window name for the conductor to target you by, run: ./scripts/set-label.sh '"$NAME"' from your pane. Window names are more reliable than pane titles with Grok/Claude.)'
  fi
  printf '%s\n' "$ROLE$LABEL_NOTE" | tmux load-buffer -
  tmux paste-buffer -t "$TARGET"
  tmux send-keys -t "$TARGET" C-m
  echo "Initial role prompt sent."
fi
