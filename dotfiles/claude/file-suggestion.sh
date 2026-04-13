#!/bin/bash
# Custom @ file suggestion for Claude Code
# Uses git ls-files (tracked files only) + fzf fuzzy filter
# ~30ms on 31k files — replaces default FS traversal
query=$(cat | jq -r '.query')
cd "${CLAUDE_PROJECT_DIR:-.}" || exit
git ls-files -co --exclude-standard 2>/dev/null | fzf --filter="$query" --scheme=path --tiebreak=begin,length | head -15
