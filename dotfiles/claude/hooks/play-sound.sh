#!/bin/sh
# Claude Code sound hook - plays a sound if sounds are enabled
# Toggle with: claude-sounds on/off

[ -f "${HOME}/.claude/sounds-enabled" ] || exit 0

case "$(uname)" in
  Darwin)
    afplay "$1" &
    ;;
  Linux)
    if command -v pw-play >/dev/null 2>&1; then
      pw-play "$1" &
    elif command -v paplay >/dev/null 2>&1; then
      paplay "$1" &
    fi
    ;;
esac
