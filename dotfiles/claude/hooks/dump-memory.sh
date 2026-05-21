#!/usr/bin/env sh
enc=$(printf '%s' "$PWD" | sed 's|[/.]|-|g')
f="$HOME/.claude/projects/${enc}/memory/MEMORY.md"
[ -f "$f" ] && cat "$f"
exit 0
