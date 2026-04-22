#!/usr/bin/env bash
# One-shot voice query: record → transcribe → ask Claude → speak response
#
# Usage:
#   voice-claude                    # New session
#   voice-claude --continue         # Resume most recent session
#   voice-claude --resume <id>      # Resume specific session

VOICE_LIB="${VOICE_LIB:-$HOME/.local/share/voice-lib.sh}"
# shellcheck source=/dev/null
. "$VOICE_LIB" || { echo "Missing: $VOICE_LIB" >&2; exit 1; }

VOICE_CLAUDE_SPEAK="${VOICE_CLAUDE_SPEAK:-1}"

CLAUDE_ARGS=""
while [ $# -gt 0 ]; do
  case $1 in
    --continue|-c) CLAUDE_ARGS="--continue"; shift ;;
    --resume|-r) CLAUDE_ARGS="--resume $2"; shift 2 ;;
    --help|-h) echo "Usage: voice-claude [--continue | --resume <session_id>]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

require_cmds curl jq ffmpeg claude

audio_file="$VOICE_TMPDIR/voice-claude-$$.mp3"
if [ -z "${VOICE_DEBUG:-}" ]; then
  trap 'rm -f "$audio_file"' EXIT
fi

record_audio "$audio_file"

if [ -n "${VOICE_DEBUG:-}" ]; then
  size=$(wc -c < "$audio_file" 2>/dev/null || echo 0)
  echo "[debug] captured $size bytes -> $audio_file" >&2
  ffmpeg -nostdin -i "$audio_file" -af volumedetect -f null - 2>&1 \
    | awk '/Duration:|mean_volume|max_volume/ {print "[debug] " $0}' >&2
fi

echo "Transcribing..."
prompt=$(transcribe "$audio_file")

[ -z "$prompt" ] && { echo "No speech detected" >&2; exit 1; }
echo "> $prompt"

echo "Asking Claude..."
# shellcheck disable=SC2086 # intentional word splitting for CLAUDE_ARGS
response=$(claude -p "$prompt" --bare --system-prompt "$VOICE_SYSTEM_PROMPT" $CLAUDE_ARGS)
echo ""
echo "$response"

if [ "$VOICE_CLAUDE_SPEAK" = "1" ] && [ -n "$response" ]; then
  speak "$response"
fi
