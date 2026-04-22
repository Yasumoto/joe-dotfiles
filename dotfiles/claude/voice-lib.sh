#!/usr/bin/env bash
# Shared voice functions for Claude voice scripts
# Sourced by: voice-claude, claude-listen, claude-speak, claude-drive

# shellcheck disable=SC2034 # used by scripts that source this library
VOICE_TMPDIR="${TMPDIR:-/tmp}"
# shellcheck disable=SC2034
VOICE_SYSTEM_PROMPT="You are a helpful voice assistant. Respond concisely in plain text, no markdown."

# xAI voice API config
XAI_API_BASE="${XAI_API_BASE:-https://api.x.ai/v1}"
XAI_VOICE="${XAI_VOICE:-eve}"
XAI_LANG="${XAI_LANG:-en}"
XAI_TTS_MAX_CHARS=15000
XAI_KEY_FILE="${XAI_KEY_FILE:-$HOME/grok.txt}"
XAI_CURL_OPTS=(--connect-timeout 10 --max-time 30)

# Platform detection — resolved once at source time
IS_DARWIN=false
[ "$(uname)" = "Darwin" ] && IS_DARWIN=true

if $IS_DARWIN; then
  FFMPEG_INPUT="-f avfoundation -i :default"
else
  FFMPEG_INPUT="-f pulse -i default"
fi

require_cmds() {
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Missing: $cmd" >&2; exit 1; }
  done
}

record_audio() {
  local audio_file="$1"
  local ffmpeg_log="$VOICE_TMPDIR/voice-ffmpeg-$$.log"
  local ctrl_fifo="$VOICE_TMPDIR/voice-ctrl-$$"
  rm -f "$ctrl_fifo"
  mkfifo "$ctrl_fifo" || return 1
  stty sane < /dev/tty 2>/dev/null
  printf '\a'
  echo "Recording... (press any key to stop)"
  # ffmpeg reads 'q' on stdin to quit gracefully and finalize the MP3.
  # SIGINT/SIGTERM get queued but not serviced until the avfoundation read
  # returns, so a signal-based stop truncates the output file.
  # shellcheck disable=SC2086 # intentional word splitting for ffmpeg flags
  ffmpeg -y $FFMPEG_INPUT -ac 1 -ar 16000 -b:a 64k -f mp3 "$audio_file" \
    < "$ctrl_fifo" >/dev/null 2>"$ffmpeg_log" &
  local pid=$!
  exec 9>"$ctrl_fifo"
  while kill -0 "$pid" 2>/dev/null; do
    if read -t 0.1 -r -n 1 < /dev/tty 2>/dev/null; then
      break
    fi
  done
  printf 'q\n' >&9
  exec 9>&-
  wait "$pid" 2>/dev/null
  rm -f "$ctrl_fifo"
  local size
  size=$(wc -c < "$audio_file" 2>/dev/null || echo 0)
  if [ "$size" -lt 5000 ]; then
    echo "Warning: short recording ($size bytes). ffmpeg stderr tail:" >&2
    tail -10 "$ffmpeg_log" >&2
  fi
  rm -f "$ffmpeg_log"
}

resolve_xai_key() {
  if [ -n "${XAI_API_KEY:-}" ]; then
    printf '%s' "$XAI_API_KEY"
    return 0
  fi
  if [ -f "$XAI_KEY_FILE" ]; then
    local perms
    perms=$(stat -f '%A' "$XAI_KEY_FILE" 2>/dev/null || stat -c '%a' "$XAI_KEY_FILE" 2>/dev/null)
    case "$perms" in
      600|400) ;;
      ?*) echo "Warning: $XAI_KEY_FILE has mode $perms (expected 600)" >&2 ;;
    esac
  fi
  local key
  key=$(tr -d '[:space:]' < "$XAI_KEY_FILE" 2>/dev/null)
  if [ -n "$key" ]; then
    printf '%s' "$key"
    return 0
  fi
  echo "Error: XAI_API_KEY not set and no key found in $XAI_KEY_FILE" >&2
  return 1
}

transcribe() {
  local audio_file="$1"
  local key
  key=$(resolve_xai_key) || return 1

  local response
  if ! response=$(curl -sS --fail-with-body "${XAI_CURL_OPTS[@]}" -X POST "$XAI_API_BASE/stt" \
    -H "Authorization: Bearer $key" \
    -F "format=true" \
    -F "language=$XAI_LANG" \
    -F "file=@$audio_file"); then
    echo "Error: xAI STT request failed: $response" >&2
    return 1
  fi
  if [ -n "${VOICE_DEBUG:-}" ]; then
    echo "[debug] stt raw response: $response" >&2
  fi
  printf '%s' "$response" | jq -r '.text // empty'
}

_tts_to_file() {
  local text="$1" out="$2" key
  key=$(resolve_xai_key) || return 1

  if [ ${#text} -gt $XAI_TTS_MAX_CHARS ]; then
    text="${text:0:$XAI_TTS_MAX_CHARS}"
  fi

  local payload
  payload=$(jq -n \
    --arg text "$text" \
    --arg voice "$XAI_VOICE" \
    --arg lang "$XAI_LANG" \
    '{text: $text, voice_id: $voice, language: $lang}')

  local http_code
  http_code=$(curl -sS "${XAI_CURL_OPTS[@]}" -X POST "$XAI_API_BASE/tts" \
    -H "Authorization: Bearer $key" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    --output "$out" \
    --write-out '%{http_code}') || true
  if [ "$http_code" != "200" ]; then
    echo "Error: xAI TTS request failed (HTTP $http_code): $(head -c 500 "$out" 2>/dev/null)" >&2
    rm -f "$out"
    return 1
  fi
}

_play_audio() {
  local audio_file="$1" mode="${2:-fg}"
  local cmd
  if $IS_DARWIN; then
    cmd=(afplay "$audio_file")
  elif command -v play >/dev/null 2>&1; then
    cmd=(play -q "$audio_file")
  elif command -v ffplay >/dev/null 2>&1; then
    cmd=(ffplay -autoexit -nodisp -loglevel quiet "$audio_file")
  else
    echo "Error: no audio player available (need afplay, play, or ffplay)" >&2
    return 1
  fi
  # Detach stdin; players don't need it and leaving it attached perturbs TTY state for downstream PTT reads.
  if [ "$mode" = "bg" ]; then
    "${cmd[@]}" </dev/null 2>/dev/null &
    echo $!
  else
    "${cmd[@]}" </dev/null 2>/dev/null
  fi
}

speak_or_fallback() {
  speak "$1" || { $IS_DARWIN && say "$1"; }
}

speak() {
  local text="$1"
  [ -z "$text" ] && return

  local audio_file="$VOICE_TMPDIR/claude-tts-$$.mp3"
  trap 'rm -f "$audio_file"' RETURN

  _tts_to_file "$text" "$audio_file" || return 1
  _play_audio "$audio_file"
}

# Speak with barge-in: any keypress (Enter etc.) interrupts playback.
# Returns 2 if interrupted by user, 0 if playback completed, 1 on error.
speak_interruptible() {
  local text="$1"
  [ -z "$text" ] && return

  local audio_file="$VOICE_TMPDIR/claude-tts-$$.mp3"
  trap 'rm -f "$audio_file"' RETURN

  _tts_to_file "$text" "$audio_file" || return 1

  local player_pid
  player_pid=$(_play_audio "$audio_file" bg) || return 1

  while kill -0 "$player_pid" 2>/dev/null; do
    if read -t 0.1 -r -n 1 < /dev/tty 2>/dev/null; then
      kill "$player_pid" 2>/dev/null
      wait "$player_pid" 2>/dev/null
      return 2
    fi
  done
  wait "$player_pid" 2>/dev/null
}

# Short feedback tones for state transitions.
# Fire-and-forget; does not block the loop.
beep() {
  local event="$1"
  if $IS_DARWIN; then
    local sound
    case "$event" in
      start)    sound="/System/Library/Sounds/Morse.aiff" ;;
      thinking) sound="/System/Library/Sounds/Tink.aiff" ;;
      error)    sound="/System/Library/Sounds/Basso.aiff" ;;
      *) printf '\a'; return ;;
    esac
    [ -f "$sound" ] && afplay "$sound" </dev/null >/dev/null 2>&1 &
  else
    printf '\a'
  fi
}
