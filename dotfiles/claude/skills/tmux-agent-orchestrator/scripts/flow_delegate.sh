#!/usr/bin/env bash
# flow_delegate.sh - Higher-order delegation flow (multi-command orchestration).
#
# This is the recommended "conductor-friendly" way to hand off substantial work
# to a specialist agent (new or existing). It composes lower-level building blocks:
# roster, (optional) launch, set-label, send-to-agent, and wait-for-agent.
#
# Prefix "flow_" per project convention for higher-order / multi-step flows.
#
# Usage:
#   ./scripts/flow_delegate.sh <name> "Clear high-level task description..." \
#       [--role researcher|implementer|reviewer|... ] \
#       [--new] [--wait] [--timeout 300] [--notify]
#
# Behavior (when --new or name not in roster):
#   - Launches a fresh agent pane using launch-agent.sh
#   - Sets stable label via set-label.sh (from inside the new pane where possible)
#   - Registers in roster with role + task
#   - Sends a scoped, verifiable instruction
#   - (if --wait) waits for "DONE" signal
#   - Updates roster status
#
# The task description you pass should include success criteria.
# The flow will append standard conductor instructions (e.g. "Report exactly: DONE - summary").
#
# Example:
#   ./scripts/flow_delegate.sh agent-research "Investigate why the new ray jobs are OOMing on the bci cluster. Focus on memory profiling of the segmentation model. Push any useful plots to the preview pane." \
#       --role researcher --new --wait

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

NAME="${1:-}"
shift || true
TASK="${1:-}"
shift || true

if [[ -z "$NAME" || -z "$TASK" ]]; then
  echo "Usage: $0 <name> \"task description...\" [options]" >&2
  echo "  --role <role>     Suggested specialist role (researcher, implementer, ...)" >&2
  echo "  --new             Force launch of a new agent even if name exists in roster" >&2
  echo "  --wait            Wait for the agent to report DONE (uses wait-for-agent.sh)" >&2
  echo "  --timeout N       Timeout for --wait (default 300)" >&2
  echo "  --notify          After completion, attempt a notification (via host agent or simple echo)" >&2
  exit 1
fi

ROLE=""
NEW=0
WAIT=0
TIMEOUT=300
NOTIFY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="$2"; shift 2 ;;
    --new) NEW=1; shift ;;
    --wait) WAIT=1; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --notify) NOTIFY=1; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# 1. Roster lookup / decide whether to launch
ROSTER_CMD="${SCRIPT_DIR}/roster.sh"
NEED_LAUNCH=0

if [[ $NEW -eq 1 ]]; then
  NEED_LAUNCH=1
else
  existing=$("$ROSTER_CMD" get "$NAME" 2>/dev/null || echo "")
  if [[ -z "$existing" ]]; then
    NEED_LAUNCH=1
  fi
fi

TARGET=""

if [[ $NEED_LAUNCH -eq 1 ]]; then
  echo ">>> Launching new agent pane for $NAME (role=${ROLE:-unspecified})"
  LAUNCH_OUT=$("${SCRIPT_DIR}/launch-agent.sh" "$NAME" "${ROLE:+You are a $ROLE specialist. }${TASK}" "$(pwd)" --split 2>&1 || true)
  echo "$LAUNCH_OUT"

  # Try to extract target (launch-agent currently prints "Launched in %xxx" or similar)
  TARGET=$(echo "$LAUNCH_OUT" | grep -oE '%[0-9]+' | head -1 || true)
  if [[ -z "$TARGET" ]]; then
    # Fallback: re-inventory and guess by the friendly name we just used
    sleep 1
    TARGET=$("${SCRIPT_DIR}/list-agents.sh" --format json 2>/dev/null | jq -r --arg n "$NAME" '.[] | select(.friendly | ascii_downcase | contains($n | ascii_downcase)) | .pane_id' | head -1 || true)
  fi

  # Ask the newly launched agent (via its pane) to self-label for stability
  if [[ -n "$TARGET" ]]; then
    sleep 2
    "${SCRIPT_DIR}/send-to-agent.sh" "$TARGET" "Please run: ./scripts/set-label.sh $NAME   (or the full path to the script in your skill directory) so the conductor can reliably target you even if your TUI changes the pane title." --no-execute || true
  fi

  # Register in roster (build JSON safely to avoid quote injection from $TASK etc.)
  "$ROSTER_CMD" set "$NAME" "$(jq -n \
    --arg role "${ROLE:-unspecified}" \
    --arg task "$TASK" \
    --arg status "in-progress" \
    --arg pane "${TARGET:-unknown}" \
    --arg launched_at "$(date -Iseconds 2>/dev/null || date +%s)" \
    '{role:$role, task:$task, status:$status, pane:$pane, launched_at:$launched_at}')" 2>/dev/null || \
    "$ROSTER_CMD" set "$NAME" "{\"role\":\"${ROLE:-unspecified}\",\"task\":\"(see roster)\",\"status\":\"in-progress\"}"
else
  echo ">>> Reusing existing agent $NAME from roster"
  TARGET=$("$ROSTER_CMD" get "$NAME" | jq -r '.pane // empty' 2>/dev/null || true)
  "$ROSTER_CMD" update "$NAME" task "$TASK"
  "$ROSTER_CMD" update "$NAME" status "in-progress"
fi

if [[ -z "$TARGET" ]]; then
  echo "Warning: Could not determine reliable target for $NAME. Falling back to name." >&2
  TARGET="$NAME"
fi

# 2. Send the scoped task
FULL_PROMPT="You are working as part of a team orchestrated by me (the conductor).
Task: $TASK

Success criteria:
- Focus only on the requested work.
- Use the preview pane for any large artifacts, diagrams, or outputs the rest of the team should see.
- When you are completely done, output on its own line exactly: DONE - <one-sentence summary of what you accomplished and any key artifacts or decisions>.

Begin."

echo ">>> Delegating to $NAME ($TARGET)"
"${SCRIPT_DIR}/send-to-agent.sh" "$TARGET" "$FULL_PROMPT"

# 3. Optional wait + roster update
if [[ $WAIT -eq 1 ]]; then
  echo ">>> Waiting for completion signal from $NAME (timeout ${TIMEOUT}s)..."
  if "${SCRIPT_DIR}/wait-for-agent.sh" "$TARGET" --timeout "$TIMEOUT" --pattern "DONE"; then
    "$ROSTER_CMD" mark "$NAME" done "Completed via flow_delegate"
    echo ">>> $NAME reported completion."
    if [[ $NOTIFY -eq 1 ]]; then
      echo "[NOTIFY] $NAME has completed its delegated task: $TASK"
      # Hook for host agent notifications (Telegram, TTS, etc.) can be added here or in the calling agent
    fi
  else
    "$ROSTER_CMD" mark "$NAME" blocked "Timed out waiting for DONE"
    echo ">>> Timed out waiting for $NAME" >&2
    exit 1
  fi
else
  echo ">>> Delegation sent (no --wait). Use roster.sh + capture-agent.sh + wait-for-agent.sh to follow up."
fi

echo "flow_delegate complete for $NAME"
