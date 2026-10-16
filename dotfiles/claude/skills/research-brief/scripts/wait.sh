#!/bin/sh
# Block until a research brief is done (or parked), then exit 0.
#
# Usage: wait.sh BRIEF.md [TIMEOUT_SECONDS]
#   TIMEOUT_SECONDS  default 3600: the longest brief so far took ~25 min.
#
# Done = a "released" line exists under Claimed by AND Findings no longer holds the
# "_(fill in place)_" placeholder. Exits 1 on timeout, 3 if the researcher's log
# shows it exited without releasing (crash, auth failure, turn cap).
set -eu

brief=${1:?usage: wait.sh BRIEF.md [TIMEOUT_SECONDS]}
timeout=${2:-3600}
log=${brief%.md}.grok.log
interval=15 # seconds; briefs take minutes, so polling faster buys nothing

elapsed=0
while [ "$elapsed" -lt "$timeout" ]; do
	if grep -q '^  - released ' "$brief" && ! grep -q '^_(fill in place)_$' "$brief"; then
		grep -m1 '^  - released ' "$brief"
		exit 0
	fi
	# The researcher writes the JSON result to the log only when it exits.
	if [ -f "$log" ] && grep -q '"stopReason"' "$log" && ! grep -q '^  - released ' "$brief"; then
		echo "researcher exited without releasing; see $log" >&2
		exit 3
	fi
	if [ -f "$log" ] && grep -qE '^Error:|"http_status": *40[13]' "$log"; then
		echo "researcher failed; see $log" >&2
		exit 3
	fi
	sleep "$interval"
	elapsed=$((elapsed + interval))
done
echo "timed out after ${timeout}s waiting on $brief" >&2
exit 1
