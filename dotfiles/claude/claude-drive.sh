#!/usr/bin/env bash
# Hands-free continuous voice loop for Claude Code
# Designed for car use: press Enter to end turn, auto-speak responses, session resume.
#
# Usage:
#   claude-drive                       # Start fresh session (PTT mode)
#   claude-drive --continue | -c       # Resume most recent session
#   DRIVE_MODE=auto claude-drive       # ffmpeg silencedetect (quieter envs)
#
# Env:
#   DRIVE_MODE       ptt (default) | auto
#   SILENCE_DURATION auto mode: seconds of silence to end turn (default 2.0)
#   NOISE_DB         auto mode: silence threshold (default -30dB)
#   MAX_DURATION     all modes: max seconds per turn (default 120)

VOICE_LIB="${VOICE_LIB:-$HOME/.local/share/voice-lib.sh}"
# shellcheck source=/dev/null
. "$VOICE_LIB" || { echo "Missing: $VOICE_LIB" >&2; exit 1; }

DRIVE_MODE="${DRIVE_MODE:-ptt}"
SILENCE_DURATION="${SILENCE_DURATION:-2.0}"
NOISE_DB="${NOISE_DB:--30dB}"
MAX_DURATION="${MAX_DURATION:-120}"

ts() { date "+%H:%M:%S"; }
log() { echo "[$(ts)] $*"; }

require_cmds curl jq ffmpeg claude

CLAUDE_ARGS=()
case "${1:-}" in
  --continue|-c) CLAUDE_ARGS=("--continue") ;;
esac

FFMPEG_PID=""
cleanup() {
  rm -f "$VOICE_TMPDIR/claude-drive-$$.mp3" \
        "$VOICE_TMPDIR/claude-drive-$$-ffmpeg.log" \
        "$VOICE_TMPDIR/claude-drive-$$-ctrl"
  [ -n "$FFMPEG_PID" ] && kill "$FFMPEG_PID" 2>/dev/null
}
trap 'log "Exiting..."; cleanup; exit 0' INT TERM
trap cleanup EXIT

# stdbuf for unbuffered ffmpeg stderr in auto mode
if command -v stdbuf >/dev/null 2>&1; then
  FFMPEG_CMD="stdbuf -oL -eL ffmpeg"
else
  FFMPEG_CMD="ffmpeg"
fi

# --- capture modes -----------------------------------------------------------

capture_ptt() {
  local audio_file="$1"
  local ffmpeg_log="$VOICE_TMPDIR/claude-drive-$$-ffmpeg.log"
  local ctrl_fifo="$VOICE_TMPDIR/claude-drive-$$-ctrl"
  rm -f "$ffmpeg_log" "$ctrl_fifo"
  mkfifo "$ctrl_fifo" || return 1
  stty sane < /dev/tty 2>/dev/null
  log "Listening... (press any key to stop)"
  # ffmpeg reads 'q' on stdin to quit and finalize the MP3. SIGINT/SIGTERM
  # get queued but not serviced until avfoundation returns, which truncates
  # the output file — see voice-lib.sh record_audio for details.
  # shellcheck disable=SC2086 # intentional word splitting for ffmpeg flags
  ffmpeg -y $FFMPEG_INPUT -ac 1 -ar 16000 -b:a 64k -f mp3 -t "$MAX_DURATION" \
    "$audio_file" < "$ctrl_fifo" >/dev/null 2>"$ffmpeg_log" &
  FFMPEG_PID=$!
  exec 9>"$ctrl_fifo"
  while kill -0 "$FFMPEG_PID" 2>/dev/null; do
    if read -t 0.1 -r -n 1 < /dev/tty 2>/dev/null; then
      break
    fi
  done
  printf 'q\n' >&9
  exec 9>&-
  wait "$FFMPEG_PID" 2>/dev/null
  rm -f "$ctrl_fifo"
  FFMPEG_PID=""
}

capture_auto() {
  local audio_file="$1"
  local ffmpeg_log="$VOICE_TMPDIR/claude-drive-$$-ffmpeg.log"
  local ctrl_fifo="$VOICE_TMPDIR/claude-drive-$$-ctrl"
  rm -f "$ffmpeg_log" "$ctrl_fifo"
  mkfifo "$ctrl_fifo" || return 1
  log "Listening... (silence detection)"
  # shellcheck disable=SC2086 # intentional word splitting for ffmpeg flags
  $FFMPEG_CMD -y $FFMPEG_INPUT -ac 1 -ar 16000 -b:a 64k -f mp3 \
    -af "silencedetect=noise=$NOISE_DB:duration=$SILENCE_DURATION" \
    -t "$MAX_DURATION" "$audio_file" \
    < "$ctrl_fifo" >/dev/null 2>"$ffmpeg_log" &
  FFMPEG_PID=$!
  exec 9>"$ctrl_fifo"

  local saw_speech=false speech_time=$SECONDS stopped=false
  while kill -0 "$FFMPEG_PID" 2>/dev/null; do
    if ! $saw_speech && grep -q "silence_end" "$ffmpeg_log" 2>/dev/null; then
      saw_speech=true
      speech_time=$SECONDS
    fi
    if $saw_speech && [ $((SECONDS - speech_time)) -ge 2 ] && \
       grep -q "silence_start" "$ffmpeg_log" 2>/dev/null; then
      printf 'q\n' >&9
      stopped=true
      break
    fi
    sleep 0.1
  done
  $stopped || printf 'q\n' >&9
  exec 9>&-
  wait "$FFMPEG_PID" 2>/dev/null
  rm -f "$ctrl_fifo"
  FFMPEG_PID=""
}

# --- main loop ---------------------------------------------------------------

log "Claude drive mode ready ($DRIVE_MODE)."
tts_stderr="$VOICE_TMPDIR/claude-drive-$$-tts.log"
if ! speak "Claude drive mode ready." 2>"$tts_stderr"; then
  log "Warning: initial TTS failed — check network."
  [ -s "$tts_stderr" ] && tail -10 "$tts_stderr" >&2
fi
rm -f "$tts_stderr"

empty_count=0
mic_checked=false
while true; do
  beep start

  audio_file="$VOICE_TMPDIR/claude-drive-$$.mp3"
  rm -f "$audio_file"
  if [ "$DRIVE_MODE" = "auto" ]; then
    capture_auto "$audio_file"
  else
    capture_ptt "$audio_file"
  fi

  file_size=$(wc -c < "$audio_file" 2>/dev/null || echo 0)
  log "Recorded ${file_size} bytes"
  ffmpeg_log="$VOICE_TMPDIR/claude-drive-$$-ffmpeg.log"
  if [ ! -f "$audio_file" ] || [ "$file_size" -lt 5000 ]; then
    log "Short file ($file_size bytes) — mic muted, cut off, or device error?"
    if [ -f "$ffmpeg_log" ]; then
      log "ffmpeg stderr tail:"
      tail -10 "$ffmpeg_log" >&2
    fi
    rm -f "$audio_file"
    empty_count=$((empty_count + 1))
    if [ "$empty_count" -ge 5 ]; then
      log "Still listening..."
      speak "Still listening. Say something or say quit to exit."
      empty_count=0
    fi
    continue
  fi

  if ! $mic_checked; then
    mean_db=$(ffmpeg -nostdin -i "$audio_file" -af volumedetect -f null - 2>&1 \
      | awk -F': ' '/mean_volume/ {gsub(/ dB/,"",$2); print $2; exit}')
    mean_int=${mean_db%.*}
    if [ "${mean_int:-0}" -le -85 ] 2>/dev/null; then
      log "All-silent capture (mean_volume=${mean_db} dB) — check Microphone permission for this terminal"
      beep error
      speak "Microphone appears muted. Check system privacy settings."
      rm -f "$audio_file"
      continue
    fi
    mic_checked=true
  fi

  beep thinking
  log "Transcribing..."
  prompt=$(transcribe "$audio_file")
  if [ -n "${DRIVE_DEBUG:-}" ]; then
    cp "$audio_file" "$VOICE_TMPDIR/claude-drive-debug-$(date +%H%M%S).mp3"
  fi
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
    *"scratch that"*|*"never mind"*|*"nevermind"*|*"cancel"*)
      log "Cancel phrase detected — skipping turn"
      beep error
      continue
      ;;
  esac

  log "You said: $prompt"
  beep thinking
  log "Asking Claude..."

  claude_stderr="$VOICE_TMPDIR/claude-drive-$$-stderr.log"
  response=$(claude -p "$prompt" \
      --system-prompt "$VOICE_SYSTEM_PROMPT" \
      "${CLAUDE_ARGS[@]}" 2>"$claude_stderr")
  claude_rc=$?
  if [ $claude_rc -ne 0 ]; then
    log "Claude error (exit $claude_rc)"
    if [ -s "$claude_stderr" ]; then
      log "claude stderr:"
      tail -20 "$claude_stderr" >&2
    fi
    rm -f "$claude_stderr"
    beep error
    speak_or_fallback "Sorry, couldn't process that."
    continue
  fi
  rm -f "$claude_stderr"

  if [ -z "$response" ]; then
    log "Empty response"
    beep error
    speak "Sorry, I got an empty response."
    continue
  fi

  # Only latch --continue after a successful, non-empty turn so an empty turn
  # doesn't poison the next one.
  CLAUDE_ARGS=("--continue")

  log "Response: $response"

  # Cap at 2000 chars for driver attention span, not xAI's 15k limit.
  spoken="$response"
  if [ ${#spoken} -gt 2000 ]; then
    spoken="${spoken:0:2000}. Response truncated."
  fi

  speak_interruptible "$spoken"
  case $? in
    2) log "Barge-in: response interrupted" ;;
    1)
      log "TTS failed"
      beep error
      $IS_DARWIN && say "$spoken"
      ;;
  esac

  log "Done."
done
