#!/usr/bin/env bash
# TTS helper: speak text from arguments or stdin
#
# Usage:
#   claude-speak "hello world"
#   echo "hello" | claude-speak

VOICE_LIB="${VOICE_LIB:-$HOME/.local/share/voice-lib.sh}"
# shellcheck source=/dev/null
. "$VOICE_LIB" || { echo "Missing: $VOICE_LIB" >&2; exit 1; }

if [ $# -gt 0 ]; then
  text="$*"
else
  text=$(cat)
fi

[ -z "$text" ] && { echo "Error: No text provided" >&2; exit 1; }

speak "$text"
