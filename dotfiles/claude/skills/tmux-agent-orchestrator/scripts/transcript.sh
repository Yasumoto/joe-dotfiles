#!/usr/bin/env bash
# transcript.sh - Access full session transcripts for reliable context beyond tmux scrollback.
#
# Primary use: when capture-agent.sh is insufficient (limited history, TUI noise, post-compaction loss).
# Grok sessions are the rich target (chat_history.jsonl, summary.json, etc.).
# Claude sessions currently expose only lightweight metadata.
#
# Resolution prefers the same friendly-name / pane logic as the rest of the skill.
#
# Usage examples:
#   ./scripts/transcript.sh tf-drift-solution --summary
#   ./scripts/transcript.sh agent-voice-mcp --grep "rearch|plan" --context 3
#   ./scripts/transcript.sh transcript-impl --last-turns 8
#   ./scripts/transcript.sh %243 --file chat_history.jsonl | tail -c 50k
#
# Set TMUX_EXEC_PREFIX for remote/distrobox (see common.sh).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

MODE="summary"
PATTERN=""
CONTEXT=2
LAST_N=5
FILE=""
SESSION_ID=""
RAW=false
HELP=false
CWD_OVERRIDE=""
TARGET=""

# Parse options first (support --cwd before or after the target)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary) MODE="summary"; shift ;;
    --grep) PATTERN="$2"; MODE="grep"; shift 2 ;;
    --context) CONTEXT="$2"; shift 2 ;;
    --last-turns) MODE="last-turns"; LAST_N="$2"; shift 2 ;;
    --file) FILE="$2"; MODE="file"; shift 2 ;;
    --session-id) SESSION_ID="$2"; shift 2 ;;
    --raw) RAW=true; shift ;;
    --cwd) CWD_OVERRIDE="$2"; shift 2 ;;
    -h|--help) HELP=true; shift ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "$TARGET" ]]; then
        TARGET="$1"
      else
        echo "Unexpected positional argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary) MODE="summary"; shift ;;
    --grep) PATTERN="$2"; MODE="grep"; shift 2 ;;
    --context) CONTEXT="$2"; shift 2 ;;
    --last-turns) MODE="last-turns"; LAST_N="$2"; shift 2 ;;
    --file) FILE="$2"; MODE="file"; shift 2 ;;
    --session-id) SESSION_ID="$2"; shift 2 ;;
    --raw) RAW=true; shift ;;
    --cwd) CWD_OVERRIDE="$2"; shift 2 ;;
    -h|--help) HELP=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if $HELP || [[ -z "$TARGET" && -z "$CWD_OVERRIDE" ]]; then
  cat <<'EOF'
transcript.sh <target> [options]
  target: friendly name (from list-agents/roster), %pane_id, or window spec.
          If it looks like an absolute path, it is used directly as cwd.

Options:
  --summary                 Show summary.json + prompt_context (default)
  --grep PATTERN            Search chat_history (and updates) for PATTERN
  --context N               Lines of context for --grep (default 2)
  --last-turns N            Pretty-print last N turns (user/assistant)
  --file FILENAME           Dump a specific file from the session dir
  --session-id ID           Use a specific UUID session instead of latest
  --raw                     Emit raw file content (no jq pretty-printing)
  --cwd PATH                Override: use this directory instead of resolving a pane
  -h, --help

Environment: respects TMUX_EXEC_PREFIX (remote/distrobox).
Roster is consulted only as a fallback for pane lookup.
EOF
  exit 0
fi

# Resolve target to a cwd (pane or direct)
get_cwd() {
  if [[ -n "$CWD_OVERRIDE" ]]; then
    printf '%s' "$CWD_OVERRIDE"
    return
  fi
  local t="$1"
  if [[ "$t" == /* || "$t" == ~* ]]; then
    printf '%s' "$t" | sed "s|^~|$HOME|"
    return
  fi
  # Try pane resolution (same heuristic style as list-agents/send-to)
  if [[ ! "$t" =~ ^(%[0-9]+|[^:]+:[0-9]) ]]; then
    local cand
    cand=$(tmux list-panes -a -F '#{pane_id} #{pane_title} #{window_name} #{window_index} #{pane_current_path}' 2>/dev/null | \
      awk -v name="$t" '
        BEGIN { lname = tolower(name) }
        {
          pid=$1; title=$2; wname=$3; widx=$4; ppath=$5;
          win_spec = widx ":" wname;
          if (wname == name || tolower(wname) == lname || index(tolower(wname), lname) || index(tolower(win_spec), lname)) {
            print ppath; exit
          }
          if (tolower(title) ~ lname || index(tolower(title), lname)) { print ppath; exit }
        }' || true)
    if [[ -n "$cand" ]]; then
      printf '%s' "$cand"
      return
    fi
  fi
  # Fallback: treat target as pane id and ask tmux
  local ppath
  ppath=$(tmux display-message -t "$t" -p '#{pane_current_path}' 2>/dev/null || true)
  if [[ -n "$ppath" ]]; then
    printf '%s' "$ppath"
    return
  fi
  # Last resort: assume the string is the cwd itself
  printf '%s' "$t" | sed "s|^~|$HOME|"
}

CWD=$(get_cwd "${TARGET:-}")
if [[ -z "$CWD" || ! -d "$CWD" ]]; then
  echo "transcript.sh: could not resolve a usable cwd for target '${TARGET:-}' (cwd-override=${CWD_OVERRIDE:-})" >&2
  exit 1
fi

# URL-encode the cwd for the sessions directory (Grok layout)
encode_path() {
  # Prefer jq if present (handles everything correctly)
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -Rr @uri
  else
    # Portable fallback (good enough for /Users/... paths)
    printf '%s' "$1" | sed 's|/|%2F|g; s| |%20|g; s|~|%7E|g'
  fi
}

ENCODED=$(encode_path "$CWD")
SESSION_ROOT="$HOME/.grok/sessions/$ENCODED"

if [[ ! -d "$SESSION_ROOT" ]]; then
  # Try Claude metadata (no full history in the same layout)
  CLAUDE_META=$(python3 -c '
import json, glob, os, sys
cwd = sys.argv[1]
for f in sorted(glob.glob(os.path.expanduser("~/.claude/sessions/*.json")), key=os.path.getmtime, reverse=True):
    try:
        d = json.load(open(f))
        if d.get("cwd") == cwd or cwd.endswith(d.get("cwd","")):
            print(f + " " + json.dumps({k:d.get(k) for k in ["sessionId","cwd","status","startedAt"] if k in d}))
            sys.exit(0)
    except: pass
print("")
' "$CWD" 2>/dev/null || true)

  if [[ -n "$CLAUDE_META" ]]; then
    echo "Claude session metadata for $CWD:"
    echo "$CLAUDE_META"
    echo "(Full conversation history is not exposed in ~/.claude/sessions/*.json the same way Grok stores chat_history.jsonl.)"
    echo "Suggestion: ask the live agent in the pane to surface recent context or maintain an AGENT_PROGRESS.md file."
    exit 0
  fi

  echo "transcript.sh: no Grok session root found for $CWD (looked in $SESSION_ROOT)" >&2
  echo "Tip: the pane must have run Grok Build at least once in that exact directory." >&2
  exit 1
fi

# Pick the session
if [[ -n "$SESSION_ID" ]]; then
  SESSION_DIR="$SESSION_ROOT/$SESSION_ID"
else
  SESSION_DIR=$(ls -1dt "$SESSION_ROOT"/*/ 2>/dev/null | head -1 | sed 's|/$||' || true)
fi

if [[ -z "$SESSION_DIR" || ! -d "$SESSION_DIR" ]]; then
  echo "transcript.sh: no session directory under $SESSION_ROOT" >&2
  exit 1
fi

SESSION_ID_BASENAME=$(basename "$SESSION_DIR")

if $RAW; then
  case "$MODE" in
    file) cat "$SESSION_DIR/$FILE" ;;
    *)    cat "$SESSION_DIR/chat_history.jsonl" | tail -c 100000 ;;
  esac
  exit 0
fi

case "$MODE" in
  summary)
    echo "=== Session $SESSION_ID_BASENAME for $CWD ==="
    if [[ -f "$SESSION_DIR/summary.json" ]]; then
      cat "$SESSION_DIR/summary.json"
    fi
    echo
    if [[ -f "$SESSION_DIR/prompt_context.json" ]]; then
      echo "=== prompt_context (head) ==="
      head -c 4000 "$SESSION_DIR/prompt_context.json" | cat
    fi
    ;;

  grep)
    if [[ -z "$PATTERN" ]]; then
      echo "transcript.sh --grep requires a PATTERN" >&2
      exit 1
    fi
    echo "=== grep '$PATTERN' in $SESSION_ID_BASENAME (chat_history + updates) ==="
    {
      [[ -f "$SESSION_DIR/chat_history.jsonl" ]] && cat "$SESSION_DIR/chat_history.jsonl"
      [[ -f "$SESSION_DIR/updates.jsonl" ]] && cat "$SESSION_DIR/updates.jsonl"
    } | grep -i -B"$CONTEXT" -A"$CONTEXT" -- "$PATTERN" | head -200 || true
    ;;

  last-turns)
    echo "=== Last $LAST_N turns from $SESSION_ID_BASENAME ==="
    # Parse jsonl, extract recent user/assistant content blocks, print cleanly.
    # Uses python for robustness on the ndjson format.
    python3 - "$SESSION_DIR/chat_history.jsonl" "$LAST_N" <<'PY'
import json, sys
path, n = sys.argv[1], int(sys.argv[2])
turns = []
with open(path) as f:
    for line in f:
        try:
            obj = json.loads(line)
        except:
            continue
        t = obj.get("type") or ""
        if t in ("user", "assistant"):
            content = obj.get("content") or obj.get("message") or ""
            if isinstance(content, list):
                # common Grok content shape
                txt = " ".join(str(c.get("text","")) for c in content if isinstance(c, dict))
            else:
                txt = str(content)
            turns.append((t, txt[:2000]))
        if len(turns) > n*2:  # keep a buffer
            turns = turns[-(n*2):]
for role, txt in turns[-n:]:
    print(f"\n[{role.upper()}]")
    print(txt.strip())
    print()
PY
    ;;

  file)
    if [[ -z "$FILE" ]]; then
      echo "transcript.sh --file requires a filename (e.g. chat_history.jsonl, summary.json)" >&2
      exit 1
    fi
    if [[ ! -f "$SESSION_DIR/$FILE" ]]; then
      echo "No such file: $SESSION_DIR/$FILE" >&2
      ls "$SESSION_DIR" | head -20
      exit 1
    fi
    cat "$SESSION_DIR/$FILE"
    ;;

  *)
    echo "Unknown mode" >&2
    exit 1
    ;;
esac
