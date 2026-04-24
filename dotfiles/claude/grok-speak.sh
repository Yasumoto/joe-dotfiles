#!/usr/bin/env bash
# TTS helper: speak text from arguments or stdin
#
# Usage:
#   grok-speak "hello world"
#   echo "hello" | grok-speak
#   cat long-brief.txt | grok-speak   # auto-chunks long input

VOICE_LIB="${VOICE_LIB:-$HOME/.local/share/voice-lib.sh}"
# shellcheck source=/dev/null
. "$VOICE_LIB" || { echo "Missing: $VOICE_LIB" >&2; exit 1; }

require_cmds curl jq awk
command -v speak_long >/dev/null 2>&1 || { echo "voice-lib.sh is out of date (missing speak_long)" >&2; exit 1; }

if [ $# -gt 0 ]; then
  text="$*"
else
  text=$(cat)
fi

[ -z "$text" ] && { echo "Error: No text provided" >&2; exit 1; }

speak_long "$text"
