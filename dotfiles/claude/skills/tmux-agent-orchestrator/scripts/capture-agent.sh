#!/usr/bin/env bash
# capture-agent.sh - Capture recent, relatively clean output from a tmux pane.
# Usage: capture-agent.sh <target> [lines]
#   target: friendly name (from list-agents), pane id (%5), or window:pane spec
#   lines:  number of lines from the bottom (default 80, max 500)
#
# Tries to strip some noise (long repeated lines, obvious prompt artifacts).

set -euo pipefail

# Support for remote hosts and distrobox (see common.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

TARGET="${1:-}"
LINES="${2:-80}"
RAW_MODE=false
SEARCH_PATTERN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --raw) RAW_MODE=true; shift ;;
    --search) SEARCH_PATTERN="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 <target> [lines] [--raw] [--search PATTERN]"
      echo "  target: friendly name, %pane, or window spec"
      echo "  lines:  number of lines (default 80, max 2000)"
      echo "  --raw:  emit unfiltered capture"
      echo "  --search PATTERN: capture then grep (case-insensitive)"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <target> [lines] [--raw] [--search PATTERN]" >&2
  exit 1
fi

[[ "$LINES" =~ ^[0-9]+$ ]] || LINES=80
[[ $LINES -gt 2000 ]] && LINES=2000

# Resolve friendly name if it doesn't look like a tmux target.
# Prefer window_name / "index:window" (stable labels) over dynamic pane_title.
# Use safe one-liner awk (with {} wrapper) for portability on macOS/BSD awk.
if [[ ! "$TARGET" =~ ^(%[0-9]+|[^:]+:[0-9]) ]]; then
  awk_resolve='{ lname = tolower(name); pid = $1; title = $2; wname = $3; widx = $4; win_spec = widx ":" wname; if (wname == name || tolower(wname) == lname || index(tolower(wname), lname) || index(tolower(win_spec), lname)) { print pid; exit } ; if (tolower(title) ~ lname || index(tolower(title), lname)) { print pid; exit } }'
  CANDIDATE=$(tmux list-panes -a -F '#{pane_id} #{pane_title} #{window_name} #{window_index}' 2>/dev/null | awk -v name="$TARGET" "$awk_resolve" || true)
  if [[ -n "$CANDIDATE" ]]; then
    TARGET="$CANDIDATE"
  fi
fi

# Capture
RAW=$(tmux capture-pane -t "$TARGET" -p -S "-$LINES" -e 2>/dev/null || true)

if [[ -z "$RAW" ]]; then
  echo "No output or invalid target: $TARGET" >&2
  exit 1
fi

if $RAW_MODE; then
  echo "$RAW"
  exit 0
fi

# Stronger cleanup for Grok/Claude TUIs: strip ANSI, collapse repeats, drop common noise lines
# (spinners, thoughts, hook markers, turn summaries, long base64-ish dumps).
CLEAN=$(echo "$RAW" | \
  sed -E '
    s/\x1b\[[0-9;]*[mK]//g;          # ANSI color
    s/\x1b\][^\x07]*\x07//g;         # OSC sequences
    s/\x1b[()][AB]//g;               # charset switches
  ' | \
  awk '
    BEGIN { IGNORECASE=1 }
    /◆ Thought for|Turn completed in|user_prompt_submit|hookify|Shift\+Tab:|Ctrl\+c:cancel/ { next }
    /⠼|⠴|⠦|⠧|⠇|⠏|⠋|⠙|⠹|⠸|⠼|Thinking \.\.\.|Running:/ { next }
    {
      if ($0 == prev) {
        count++
      } else {
        if (count > 2) printf "... (%d more identical lines)\n", count-1
        if (prev != "") print prev
        count=1
      }
      prev=$0
    }
    END {
      if (count > 2) printf "... (%d more identical lines)\n", count-1
      else if (NR>0 && prev != "") print prev
    }
  ' | \
  awk '{ if (length($0) > 400) print substr($0,1,400) " …"; else print }' | \
  tail -n "$LINES"
)

if [[ -n "$SEARCH_PATTERN" ]]; then
  echo "$CLEAN" | grep -i "$SEARCH_PATTERN" || true
else
  echo "$CLEAN"
fi
