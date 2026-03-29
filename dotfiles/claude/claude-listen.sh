#!/usr/bin/env bash
# STT helper: record audio and output transcription to stdout
#
# Usage:
#   text=$(claude-listen)

VOICE_LIB="${VOICE_LIB:-$HOME/.local/share/voice-lib.sh}"
# shellcheck source=/dev/null
. "$VOICE_LIB" || { echo "Missing: $VOICE_LIB" >&2; exit 1; }

require_cmds whisper-cli ffmpeg
require_whisper_model

audio_file="$VOICE_TMPDIR/claude-listen-$$.wav"
trap 'rm -f "$audio_file"' EXIT

record_audio "$audio_file" 2>/dev/null

transcribe "$audio_file"
