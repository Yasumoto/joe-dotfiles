#!/usr/bin/env bash
# Shared voice functions for Claude voice scripts
# Sourced by: voice-claude, claude-listen, claude-speak, claude-drive

# Path must match installWhisperModel activation in home.nix
WHISPER_MODEL="${WHISPER_MODEL:-$HOME/.local/share/whisper-models/ggml-base.en.bin}"
PIPER_VOICE="${PIPER_VOICE:-$HOME/.local/share/piper-voices/en_US-lessac-medium.onnx}"
# shellcheck disable=SC2034 # used by scripts that source this library
VOICE_TMPDIR="${TMPDIR:-/tmp}"
# shellcheck disable=SC2034
VOICE_SYSTEM_PROMPT="You are a helpful voice assistant. Respond concisely in plain text, no markdown."

# Platform detection — resolved once at source time
IS_DARWIN=false
[ "$(uname)" = "Darwin" ] && IS_DARWIN=true

if $IS_DARWIN; then
  FFMPEG_INPUT="-f avfoundation -i :default"
else
  FFMPEG_INPUT="-f pulse -i default"
fi

NCPU=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)

require_cmds() {
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Missing: $cmd" >&2; exit 1; }
  done
}

require_whisper_model() {
  [ -f "$WHISPER_MODEL" ] || { echo "Whisper model not found: $WHISPER_MODEL" >&2; exit 1; }
}

record_audio() {
  local audio_file="$1"
  printf '\a'
  echo "Recording... (press Enter to stop)"
  # shellcheck disable=SC2086 # intentional word splitting for ffmpeg flags
  ffmpeg -y $FFMPEG_INPUT -ac 1 -ar 16000 -sample_fmt s16 "$audio_file" 2>/dev/null &
  local pid=$!
  read -r
  kill $pid 2>/dev/null
  wait $pid 2>/dev/null
}

transcribe() {
  local audio_file="$1"
  whisper-cli -m "$WHISPER_MODEL" -f "$audio_file" -nt -np -t "$NCPU" 2>/dev/null | \
    sed 's/\[[^]]*\]//g; s/([^)]*)//g; s/^[[:space:]]*//; s/[[:space:]]*$//' | \
    tr -s ' '
}

speak() {
  local text="$1"
  [ -z "$text" ] && return
  if $IS_DARWIN; then
    say -r 180 "$text"
  elif command -v piper >/dev/null 2>&1 && [ -f "$PIPER_VOICE" ]; then
    echo "$text" | piper --model "$PIPER_VOICE" --output_raw 2>/dev/null | \
      play -q -r 22050 -e signed -b 16 -c 1 -t raw -
  else
    echo "$text"
  fi
}
