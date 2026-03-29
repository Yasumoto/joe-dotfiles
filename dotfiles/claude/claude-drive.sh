#!/usr/bin/env bash
# Hands-free continuous voice loop for Claude Code
# Designed for car use: silence detection, auto-speak, session resume
#
# Usage:
#   claude-drive          # Resume most recent session
#   claude-drive --new    # Start fresh session

VOICE_LIB="${VOICE_LIB:-$HOME/.local/share/voice-lib.sh}"
# shellcheck source=/dev/null
. "$VOICE_LIB" || { echo "Missing: $VOICE_LIB" >&2; exit 1; }

SILENCE_DURATION="${SILENCE_DURATION:-2.0}"
NOISE_DB="${NOISE_DB:--30dB}"
MAX_DURATION="${MAX_DURATION:-120}"

ts() { date "+%H:%M:%S"; }
log() { echo "[$(ts)] $*"; }

require_cmds whisper-cli ffmpeg claude
require_whisper_model

CLAUDE_ARGS="--continue"
[ "${1:-}" = "--new" ] && CLAUDE_ARGS=""

# stdbuf for unbuffered ffmpeg stderr if available
if command -v stdbuf >/dev/null 2>&1; then
  FFMPEG_CMD="stdbuf -oL -eL ffmpeg"
else
  FFMPEG_CMD="ffmpeg"
fi

FFMPEG_PID=""
cleanup() {
  rm -f "$VOICE_TMPDIR/claude-drive-$$.wav" "$VOICE_TMPDIR/claude-drive-$$-ffmpeg.log"
  [ -n "$FFMPEG_PID" ] && kill $FFMPEG_PID 2>/dev/null
}
trap 'log "Exiting..."; cleanup; exit 0' INT TERM
trap cleanup EXIT

bump_empty() {
  empty_count=$((empty_count + 1))
  if [ "$empty_count" -ge 5 ]; then
    log "Still listening..."
    speak "Still listening. Say something or say quit to exit."
    empty_count=0
  fi
}

log "Claude drive mode ready."
speak "Claude drive mode ready."

empty_count=0
while true; do
  audio_file="$VOICE_TMPDIR/claude-drive-$$.wav"
  ffmpeg_log="$VOICE_TMPDIR/claude-drive-$$-ffmpeg.log"

  printf '\a'
  log "Listening..."

  rm -f "$audio_file" "$ffmpeg_log"
  # shellcheck disable=SC2086 # intentional word splitting for ffmpeg flags
  $FFMPEG_CMD -y $FFMPEG_INPUT -ac 1 -ar 16000 -sample_fmt s16 \
    -af "silencedetect=noise=$NOISE_DB:duration=$SILENCE_DURATION" \
    -t "$MAX_DURATION" "$audio_file" 2>"$ffmpeg_log" &
  FFMPEG_PID=$!

  saw_speech=false
  speech_time=$SECONDS
  while kill -0 $FFMPEG_PID 2>/dev/null; do
    if ! $saw_speech && grep -q "silence_end" "$ffmpeg_log" 2>/dev/null; then
      log "Speaking detected..."
      saw_speech=true
      speech_time=$SECONDS
    fi
    # Wait for post-speech silence (min 2s after speech detected)
    if $saw_speech && [ $((SECONDS - speech_time)) -ge 2 ] && \
       grep -q "silence_start" "$ffmpeg_log" 2>/dev/null; then
      log "Silence detected, stopping recording..."
      kill $FFMPEG_PID 2>/dev/null
      wait $FFMPEG_PID 2>/dev/null
      break
    fi
    sleep 0.1
  done
  wait $FFMPEG_PID 2>/dev/null

  if [ ! -f "$audio_file" ]; then
    log "No audio file produced"
    bump_empty
    continue
  fi

  file_size=$(wc -c < "$audio_file" 2>/dev/null || echo 0)
  log "Recorded ${file_size} bytes"

  if [ "$file_size" -lt 5000 ]; then
    rm -f "$audio_file"
    bump_empty
    continue
  fi

  log "Transcribing..."
  prompt=$(transcribe "$audio_file")
  rm -f "$audio_file"

  if [ -z "$prompt" ]; then
    log "No speech detected"
    continue
  fi
  empty_count=0

  case "${prompt,,}" in
    *"stop driving"*|*"exit drive"*|*"quit"*|*"goodbye"*)
      log "Exit command detected"
      speak "Ending drive mode."
      break
      ;;
  esac

  log "You said: $prompt"
  log "Asking Claude..."

  response=$(claude -p "$prompt" --bare --system-prompt "$VOICE_SYSTEM_PROMPT" $CLAUDE_ARGS) || {
    log "Claude error"
    speak "Sorry, couldn't process that."
    continue
  }
  CLAUDE_ARGS="--continue"

  if [ -z "$response" ]; then
    log "Empty response"
    speak "Sorry, I got an empty response."
    continue
  fi

  log "Response: $response"

  if [ ${#response} -gt 2000 ]; then
    speak "$(echo "$response" | head -c 2000). Response truncated."
  else
    speak "$response"
  fi

  log "Done."
done
