#!/bin/sh
# Hand a research brief to a headless Grok Build researcher in the background.
#
# Usage: dispatch.sh BRIEF.md [WORKDIR]
#   WORKDIR  directory grok starts in (default: ~/src/sw if it exists, else the
#            current git toplevel, else $PWD). The gateway auth helper resolves
#            itself from the git toplevel, so grok gets a 401 outside the checkout.
#
# Env:
#   RESEARCH_BRIEF_GROK        grok binary (default: grok on PATH, else ~/.grok/bin/grok)
#   RESEARCH_BRIEF_MAX_TURNS   headless turn cap (default 80: a 6-10 question brief
#                              took ~40 tool turns in practice; leave headroom)
#
# Prints the log path and PID on success. Exits 2 when grok is missing so the
# caller can fall back to "forward this brief by hand".
set -eu

brief=${1:?usage: dispatch.sh BRIEF.md [WORKDIR]}
[ -f "$brief" ] || { echo "no such brief: $brief" >&2; exit 1; }
brief=$(cd "$(dirname "$brief")" && pwd)/$(basename "$brief")

if [ -n "${2:-}" ]; then
	workdir=$2
elif [ -d "$HOME/src/sw" ]; then
	workdir=$HOME/src/sw
else
	workdir=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
fi

grok=${RESEARCH_BRIEF_GROK:-$(command -v grok 2>/dev/null || true)}
[ -n "$grok" ] || [ ! -x "$HOME/.grok/bin/grok" ] || grok=$HOME/.grok/bin/grok
if [ -z "$grok" ] || [ ! -x "$grok" ]; then
	echo "grok not found; forward $brief to any agent with web + x.com search" >&2
	exit 2
fi

grep -q '^\*\*Claimed by:\*\* (unclaimed)' "$brief" || {
	echo "brief already claimed; not dispatching: $brief" >&2
	exit 1
}

log=${brief%.md}.grok.log
max_turns=${RESEARCH_BRIEF_MAX_TURNS:-80}

prompt="You are a research agent. Execute the research brief at $brief exactly as its
'What you must do when you pick this up' section says: claim it, research every question
with web search, x.com search and web_fetch, fill in Findings in place with citations,
then release the claim. Edit only that one file. Never put internal hostnames, emails,
tokens or ticket links into a search query or fetched URL. Do not ask questions; if
something blocks you, write it into Findings, mark the claim 'parked: <why>', and stop."

# Grok deny rules beat allow rules, so "deny all edits, allow the brief" would block
# the brief too. Instead deny edits inside the checkout grok runs from (briefs live
# outside it) and the shell commands that mutate infra or delete files. The prompt
# carries the "edit only the brief" rule for everything else.
case $brief in
"$workdir"/*) edit_deny="" ;;
*) edit_deny="$workdir/**" ;;
esac
set -- --deny "Bash(rm *)" --deny "Bash(git push*)" --deny "Bash(kubectl*)" --deny "Bash(terraform*)"
[ -z "$edit_deny" ] || set -- "$@" --deny "Edit($edit_deny)" --deny "Write($edit_deny)"

# Otherwise the researcher inherits the caller's identity and stamps the caller's
# session and tmux pane into its claim line.
unset CLAUDECODE CLAUDE_CODE_SESSION_ID CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_CHILD_SESSION TMUX_PANE

cd "$workdir"
nohup "$grok" -p "$prompt" \
	--max-turns "$max_turns" \
	--output-format json \
	--disallowed-tools "Agent,image_gen,image_edit,image_to_video,reference_to_video,scheduler_create,workflow" \
	"$@" \
	>"$log" 2>&1 </dev/null &
pid=$!

echo "dispatched pid=$pid log=$log workdir=$workdir"
