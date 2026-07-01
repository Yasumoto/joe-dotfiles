#!/usr/bin/env bash
# wait-for-agent.sh - Block until a target agent reports completion or a pattern.
#
# This is a core low-level building block for delegation and orchestration flows.
# It polls using capture-agent.sh and looks for signals.
#
# Usage:
#   ./scripts/wait-for-agent.sh <target> [--timeout 300] [--pattern "DONE"] [--interval 5]
#
# The target agent should be instructed (via send-to-agent) to end with a clear signal,
# e.g. "When you are done, output exactly: DONE - <one sentence summary>"
#
# Returns 0 on success (pattern seen), 1 on timeout or error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

TARGET="${1:-}"
shift || true

TIMEOUT=300
PATTERN="DONE"
INTERVAL=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --pattern) PATTERN="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <target> [--timeout 300] [--pattern \"DONE\"] [--interval 5]" >&2
  exit 1
fi

start=$(date +%s)
echo "Waiting for $TARGET to report '$PATTERN' (timeout ${TIMEOUT}s)..."

while true; do
  now=$(date +%s)
  if (( now - start > TIMEOUT )); then
    echo "Timeout waiting for $TARGET after ${TIMEOUT}s" >&2
    exit 1
  fi

  # Use capture-agent for recent output (respects common.sh remote prefix)
  output=$("${SCRIPT_DIR}/capture-agent.sh" "$TARGET" 30 2>/dev/null || true)

  if echo "$output" | grep -qi "$PATTERN"; then
    echo "Detected '$PATTERN' from $TARGET"
    # Print the matching line(s) for context
    echo "$output" | grep -i "$PATTERN" | tail -3
    exit 0
  fi

  sleep "$INTERVAL"
done
