#!/usr/bin/env bash
# STT helper: record audio and output transcription to stdout
#
# Usage:
#   text=$(claude-listen)

VOICE_LIB="${VOICE_LIB:-$HOME/.local/share/voice-lib.sh}"
# shellcheck source=/dev/null
. "$VOICE_LIB" || { echo "Missing: $VOICE_LIB" >&2; exit 1; }

require_cmds curl jq ffmpeg

audio_file="$VOICE_TMPDIR/claude-listen-$$.mp3"
trap 'rm -f "$audio_file"' EXIT

record_audio "$audio_file"

transcribe "$audio_file"
