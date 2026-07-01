#!/usr/bin/env bash
# preview-push.sh - Push a file to the shared "preview" pane/window using your established convention.
# Usage: preview-push.sh <path> [preview-target]
#
# preview-target defaults to "preview" (window or pane title).
# It tries to clear the preview (send 'q' if in a pager) then run `preview "path"`.

set -euo pipefail

# Support for remote hosts and distrobox (see common.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

PATH_TO_SHOW="${1:-}"
PREVIEW_TARGET="${2:-preview}"

if [[ -z "$PATH_TO_SHOW" ]]; then
  echo "Usage: $0 <path> [preview-target]" >&2
  exit 1
fi

# Resolve friendly preview target to a real spec if needed.
# Prefer stable window_name / "index:window" matches over dynamic pane titles.
if [[ ! "$PREVIEW_TARGET" =~ ^(%|:) ]]; then
  CAND=$(tmux list-panes -a -F '#{pane_id} #{pane_title} #{window_name} #{window_index}' 2>/dev/null \
    | awk -v n="$PREVIEW_TARGET" '
      ln = tolower(n)
      pid=$1; title=$2; wname=$3; widx=$4
      ws = widx ":" wname
      if (wname == n || tolower(wname) == ln || index(tolower(wname), ln) || index(tolower(ws), ln)) {
        print pid; exit
      }
      if (tolower(title) ~ ln || index(tolower(title), ln)) { print pid; exit }
    ' || true)
  if [[ -n "$CAND" ]]; then
    PREVIEW_TARGET="$CAND"
  fi
fi

# Try to quit any pager, then invoke the preview command (assumed in PATH on the target pane's shell)
tmux send-keys -t "$PREVIEW_TARGET" 'q' C-m
sleep 0.2
tmux send-keys -t "$PREVIEW_TARGET" "preview \"$PATH_TO_SHOW\"" C-m

echo "Pushed $PATH_TO_SHOW to $PREVIEW_TARGET"
