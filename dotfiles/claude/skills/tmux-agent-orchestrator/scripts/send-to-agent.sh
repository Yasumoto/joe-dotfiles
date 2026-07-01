#!/usr/bin/env bash
# send-to-agent.sh - Send a message (as if typed by the user) to an agent pane.
# Usage: send-to-agent.sh <target> "the full instruction here" [--no-execute] [--force]
#
# - target: friendly name, %pane, or window spec
# - The message is sent literally then Enter (unless --no-execute)
# - For very long or complex messages, the script will use load-buffer + paste for safety.
#
# SAFETY: By default this refuses to send if the target pane does not appear to be
# running an active AI agent TUI (grok/claude/hermes etc. based on title/window/path).
# This prevents accidentally pasting long instructions into a plain bash/zsh shell
# (where they would be executed as commands or leave the prompt in a bad state).
# Always run list-agents.sh first to inspect. Use --force only if you are certain
# (e.g. you are deliberately typing a shell command via the orchestrator).

set -euo pipefail

# Support for remote hosts and distrobox (see common.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

TARGET="${1:-}"
shift || true
MESSAGE=""
NO_EXEC=0
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-execute) NO_EXEC=1; shift ;;
    --force) FORCE=1; shift ;;
    *)
      if [[ -z "$MESSAGE" ]]; then
        MESSAGE="$1"
      else
        MESSAGE="$MESSAGE $1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$TARGET" || -z "$MESSAGE" ]]; then
  echo "Usage: $0 <target> \"message text...\" [--no-execute] [--force]" >&2
  exit 1
fi

# Resolve target.
# - If it already looks like a direct tmux specifier (%pane or win:pane or session:win), use as-is.
# - Otherwise search panes for a match. Prefer stable window_name / "index:window_name" over
#   (possibly dynamic/polluted) pane_title. This makes "voice-orchestrator" or "8:voice-orchestrator"
#   or "agent-research" work reliably even when the TUI has overwritten the pane title.
if [[ ! "$TARGET" =~ ^(%[0-9]+|[^:]+:[0-9]) ]]; then
  # One-line awk program via variable. Wrap per-record logic in { } for portability across awk implementations (macOS/BSD awk etc.). Avoids top-level statement quirks.
  awk_resolve='{ lname = tolower(name); pid = $1; title = $2; wname = $3; widx = $4; win_spec = widx ":" wname; if (wname == name || tolower(wname) == lname || index(tolower(wname), lname) || index(tolower(win_spec), lname)) { print pid; exit } ; if (tolower(title) ~ lname || index(tolower(title), lname)) { print pid; exit } }'
  CANDIDATE=$(tmux list-panes -a -F '#{pane_id} #{pane_title} #{window_name} #{window_index}' 2>/dev/null | awk -v name="$TARGET" "$awk_resolve" || true)
  if [[ -n "$CANDIDATE" ]]; then
    TARGET="$CANDIDATE"
  fi
fi

# SAFETY CHECK: refuse to inject long text into panes that don't look like active AI agent TUIs.
# Always perform (even for friendly names that failed to resolve to %id).
# Plain shells (bash etc.) will interpret the pasted message (or parts of it) as commands.
# list-agents.sh is the way to discover and confirm targets first.
CUR_TITLE=$(tmux display-message -p -t "$TARGET" '#{pane_title}' 2>/dev/null || echo "")
CUR_WIN=$(tmux display-message -p -t "$TARGET" '#{window_name}' 2>/dev/null || echo "")
CUR_PATH=$(tmux display-message -p -t "$TARGET" '#{pane_current_path}' 2>/dev/null || echo "")
LOWER_CTX=$(echo "$CUR_TITLE $CUR_WIN $CUR_PATH" | tr '[:upper:]' '[:lower:]')

if [[ ! "$LOWER_CTX" =~ (grok|claude|hermes|agent-|orchestr|conductor) ]]; then
  echo "SAFETY ABORT: Target $TARGET does not appear to be running an active AI agent TUI."
  echo "  Title : '$CUR_TITLE'"
  echo "  Window: '$CUR_WIN'"
  echo "  Path  : '$CUR_PATH'"
  TPID=$(tmux display-message -p -t "$TARGET" '#{pane_pid}' 2>/dev/null || echo "")
  if [[ -n "$TPID" ]] && command -v ps >/dev/null 2>&1; then
    PCMD=$(ps -p "$TPID" -o comm= 2>/dev/null || echo "unknown")
    echo "  Proc  : $PCMD (pid $TPID)"
  fi
  echo ""
  echo "A long natural-language message here would be pasted into the shell (or whatever is running)"
  echo "and likely executed as commands or leave the terminal in a broken state."
  echo ""
  echo "Use list-agents.sh first. Only send to panes whose title/window/path indicate a live"
  echo "agent TUI (grok/claude/hermes/agent-foo). Launch one with launch-agent.sh if needed."
  echo ""
  echo "To override this safety (at your own risk, e.g. for a short deliberate shell command):"
  echo "  send-to-agent.sh ... --force"
  if [[ $FORCE -eq 0 ]]; then
    exit 1
  fi
  echo "Proceeding with --force (you were warned)."
fi

# Use load-buffer + paste-buffer for robustness with newlines and special chars.
# Then send Enter if requested.
printf '%s\n' "$MESSAGE" | tmux load-buffer - 2>/dev/null || {
  # Fallback for very old tmux
  tmux set-buffer "$MESSAGE"
}

tmux paste-buffer -t "$TARGET" 2>/dev/null || tmux send-keys -t "$TARGET" -X paste 2>/dev/null || true

if [[ $NO_EXEC -eq 0 ]]; then
  tmux send-keys -t "$TARGET" C-m
fi

echo "Sent to $TARGET (execute=$((1-NO_EXEC)))"
