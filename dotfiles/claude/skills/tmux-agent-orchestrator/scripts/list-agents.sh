#!/usr/bin/env bash
# list-agents.sh - Discover AI agent panes/windows in the current tmux session.
# Outputs a table suitable for an orchestrator to build a roster.
#
# Usage: list-agents.sh [--session <name>] [--format table|json]
#
# Heuristics for "agent-like":
# - Pane/window title contains agent-*, claude, grok, hermes, code, research, impl, review, etc.
# - Current command looks like claude/grok/hermes (from ps or pane title)
# - User can override by setting pane titles with `tmux select-pane -T "agent-foo"`
#
# Accuracy notes (for dynamic TUIs like Grok Build / Claude Code):
# - Window names (set with rename-window) are stable and used preferentially for FRIENDLY labels.
# - Pane titles are aggressively cleaned of "Running:...", spinners (⠼), " - grok", "Thinking" etc.
# - The pane running the list is marked "@" and "(self)" / "(orchestrator)" using CURRENT_PANE.
# - See set-label.sh for a helper to reliably label the *current* pane's window + title.

set -euo pipefail

# Support for remote hosts and distrobox (see common.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

SESSION=""
FORMAT="table"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session) SESSION="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--session <name>] [--format table|json]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Determine target session
if [[ -z "$SESSION" ]]; then
  # Prefer the session we're attached to, else first non-attached, else default
  if [[ -n "${TMUX:-}" ]]; then
    SESSION=$(tmux display-message -p '#{session_name}' 2>/dev/null || echo "")
  fi
  if [[ -z "$SESSION" ]]; then
    SESSION=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | head -1 || echo "")
  fi
fi

if [[ -z "$SESSION" ]]; then
  echo "No tmux session found." >&2
  exit 1
fi

# Get panes with useful fields. We use -a for all panes across windows in the session.
# Fields: pane_id, pane_title, window_index, window_name, pane_current_path, pane_active, pane_pid
PANES=$(tmux list-panes -t "$SESSION" -a -F \
  '#{pane_id}	#{pane_title}	#{window_index}	#{window_name}	#{pane_current_path}	#{pane_active}	#{pane_pid}' 2>/dev/null || true)

if [[ -z "$PANES" ]]; then
  echo "No panes found in session $SESSION" >&2
  exit 0
fi

# Current pane (the one running this list) for self-identification. This is the most reliable
# way to know "us" even when titles are being dynamically updated by the TUI.
CURRENT_PANE=$(tmux display-message -p '#{pane_id}' 2>/dev/null || echo "")

# clean_title: strip Grok/Claude/Hermes TUI noise (spinners, "Running: ...", "Thinking", " - grok")
# so that dynamic titles don't pollute friendly names. Window names (set via rename-window)
# are preferred as they are stable and what appears in tmux status bars.
clean_title() {
  local t="${1:-}"
  # Strip leading spinners, bullets, and running/thinking prefixes commonly injected by TUIs
  t=$(printf '%s' "$t" | sed -E '
    s/^[[:space:]]*[⠋⠼⠂✳⠸⡿⣾⣽⣻⢿⡿⣟⣯⣷⣾]+[[:space:]]*//;
    s/^[[:space:]]*[-*]+[[:space:]]*//;
    s/^[[:space:]]*-[[:space:]]*Running:[[:space:]]*//I;
    s/^[[:space:]]*-[[:space:]]*Thinking[[:space:]]*-[[:space:]]*//I;
    s/[[:space:]]*-[[:space:]]*(grok|claude|hermes)[[:space:]]*$//i;
    s/[[:space:]]+$//;
  ')
  # If what remains looks like an internal command line or is overly long (polluted prompt),
  # try to recover a short human label from the end or truncate.
  if [[ "$t" =~ ^(cd[[:space:]]|/|ls[[:space:]]|which[[:space:]]|tmux[[:space:]]) ]] || [ ${#t} -gt 75 ]; then
    if [[ "$t" == *" - "* ]]; then
      t=$(printf '%s' "$t" | sed -E 's/.* - //')
    fi
    if [ ${#t} -gt 60 ]; then
      t="${t:0:57}…"
    fi
  fi
  echo "$t"
}

# Helper to guess if this looks like an agent pane
is_agent_pane() {
  local title="$1"
  local path="$2"
  local lower
  lower=$(echo "$title $path" | tr '[:upper:]' '[:lower:]')

  # Strong signals
  if [[ "$title" =~ ^agent- || "$title" =~ ^(research|impl|review|test|orchestr|conductor) ]]; then
    return 0
  fi
  if [[ "$title" =~ claude|code|grok|hermes ]]; then
    return 0
  fi
  # Weak signals from path (common monorepo or agent work dirs)
  if [[ "$lower" =~ (claude|agent|orchestr|swarm) ]]; then
    return 0
  fi
  return 1
}

# Collect and annotate
declare -a rows=()

while IFS=$'\t' read -r pane_id title win_idx win_name dir active pid; do
  is_agent=0
  if is_agent_pane "$title" "$dir"; then
    is_agent=1
  fi

  # Try to get a short command name from the pane (best effort)
  cmd=""
  if command -v ps >/dev/null 2>&1; then
    # On macOS/Linux, get the command for the pane's pid (the shell or the agent)
    cmd=$(ps -p "$pid" -o comm= 2>/dev/null | xargs || true)
    if [[ -z "$cmd" ]]; then
      # Try parent or child
      cmd=$(pgrep -P "$pid" 2>/dev/null | head -1 | xargs -I{} ps -p {} -o comm= 2>/dev/null | xargs || true)
    fi
  fi

  # Friendly name logic - key for accuracy with dynamic TUIs (Grok Build, Claude, etc.):
  # - Window names (from rename-window) are stable and shown in status bars ("8: voice-orchestrator").
  # - Pane titles are frequently overwritten with "Running: ...", spinners, prompt fragments, " - grok".
  # Prefer a non-generic window_name as the primary friendly label. Only fall back to (cleaned) title.
  # This prevents long polluted strings in the FRIENDLY column and makes targeting by name reliable.
  cleaned=$(clean_title "$title")
  if [[ -n "$win_name" && ! "$win_name" =~ ^(node|bash|zsh|fish|sh|default|0|1|2|3|4|5|6|7|8|9)$ && "$win_name" != "-" && "$win_name" != "" ]]; then
    friendly="$win_name"
  else
    friendly="$cleaned"
    if [[ -z "$friendly" || "$friendly" == "-" ]]; then
      friendly="$win_name"
    fi
  fi

  # Avoid re-appending the (already cleaned or long) title to the window name; keep FRIENDLY short.
  # Activity/prompt info is still visible in the raw title if needed, but the label for targeting is stable.

  # Status hint
  status="idle"
  if [[ "$active" == "1" ]]; then
    status="focused"
  fi

  # Only include likely agents or all if we found none? For orchestrator, show candidates.
  # Always show panes that have agent signals; otherwise show everything but mark non-agent.
  marker=""
  if [[ "$pane_id" == "$CURRENT_PANE" ]]; then
    marker="@"
  elif [[ $is_agent -eq 1 ]]; then
    marker="*"
  fi

  # Append role hint to friendly for the orchestrator/self so it's immediately obvious in the roster.
  if [[ "$pane_id" == "$CURRENT_PANE" ]]; then
    if [[ "$win_name" =~ [Oo]rchestr|[Cc]onductor|[Vv]oice ]]; then
      friendly="$friendly (orchestrator)"
    else
      friendly="$friendly (self)"
    fi
  elif [[ "$win_name" =~ [Oo]rchestr|[Cc]onductor || "$cleaned" =~ [Oo]rchestr|[Cc]onductor || "$dir" =~ tmux-agent-orchestrator ]]; then
    friendly="$friendly (orchestrator)"
  fi

  rows+=("$marker|$friendly|$pane_id|$win_idx:$win_name|$dir|$status|$cmd")
done <<< "$PANES"

if [[ ${#rows[@]} -eq 0 ]]; then
  echo "No panes."
  exit 0
fi

if [[ "$FORMAT" == "json" ]]; then
  echo "["
  first=1
  for r in "${rows[@]}"; do
    IFS='|' read -r marker friendly pane win dir status cmd <<< "$r"
    [[ $first -eq 0 ]] && echo ","
    printf '  {"marker":"%s","friendly":"%s","pane_id":"%s","window":"%s","dir":"%s","status":"%s","cmd":"%s"}' \
      "$marker" "$friendly" "$pane" "$win" "$dir" "$status" "$cmd"
    first=0
  done
  echo
  echo "]"
else
  # Table
  printf "%-1s %-22s %-6s %-18s %-35s %-10s %s\n" " " "FRIENDLY" "PANE" "WINDOW" "DIR" "STATUS" "CMD"
  printf "%-1s %-22s %-6s %-18s %-35s %-10s %s\n" " " "--------" "----" "------" "---" "------" "---"
  for r in "${rows[@]}"; do
    IFS='|' read -r marker friendly pane win dir status cmd <<< "$r"
    shortdir=$(echo "$dir" | sed "s|^$HOME|~|")
    printf "%-1s %-22s %-6s %-18s %-35s %-10s %s\n" "$marker" "$friendly" "$pane" "$win" "$shortdir" "$status" "$cmd"
  done
  echo
  echo "Legend: * = likely agent pane (heuristics on title/path/cmd). @ = current pane (where this list ran)."
  echo "        Names with (orchestrator) or (self) are the conductor. Target by FRIENDLY (substring ok),"
  echo "        PANE id (%143), or WINDOW (e.g. 'voice-orchestrator', '8:voice-orchestrator', or '8')."
  echo "        Window names (rename-window) are the most stable for Grok/Claude (pane titles are dynamic)."
  echo "        Use ./scripts/set-label.sh <name> from inside a pane to set both window + pane label reliably."
fi
