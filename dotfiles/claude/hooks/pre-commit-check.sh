#!/bin/sh
# Always exits 0: advisory only, never block a tool call.
# Emits hookSpecificOutput.additionalContext on failure so Claude sees the
# lint output next turn and can self-correct.

set -u

input=$(cat)

file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$file_path" ] || exit 0
[ -e "$file_path" ] || exit 0

repo_root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null) || exit 0

[ -f "$repo_root/.pre-commit-config.yaml" ] || exit 0

if command -v prek >/dev/null 2>&1; then
  runner=prek
elif command -v pre-commit >/dev/null 2>&1; then
  runner=pre-commit
else
  exit 0
fi

output=$(cd "$repo_root" && "$runner" run --files "$file_path" 2>&1)
status=$?

[ "$status" -eq 0 ] && exit 0

trimmed=$(printf '%s\n' "$output" | tail -60)

jq -n --arg ctx "$runner reported issues on $file_path:

$trimmed" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
