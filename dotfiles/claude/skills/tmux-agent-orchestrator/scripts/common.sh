#!/usr/bin/env bash
# common.sh - Shared helpers for tmux-agent-orchestrator scripts.
#
# Remote / distrobox / container support:
#   Set TMUX_EXEC_PREFIX before invoking the scripts (or the orchestrator shell).
#
# IMPORTANT for distrobox/podman/etc: Direct "tmux ..." after -- often fails
# with "executable not found" even when tmux is installed (PATH/OCI exec issue).
# The wrappers detect a prefix and invoke via
#   prefix sh -c 'thecmd "$@"' _ args...
# (the form where the command name is a literal token in the -c script text;
# this reliably finds the binary inside the container).
# You can use a *simple* prefix.
#
# Recommended for your remote + distrobox setup:
#   export TMUX_EXEC_PREFIX='ssh -T joe@joe-epona.int.n7k.io distrobox enter ubuntu -- '
#
# Other examples:
#   # Remote host only (tmux on the remote)
#   export TMUX_EXEC_PREFIX='ssh -T user@host'
#
#   # Remote + distrobox (tmux inside the container on the remote)
#   export TMUX_EXEC_PREFIX='ssh -T user@host distrobox enter ubuntu -- '
#
#   # Local distrobox only (orchestrator on same host)
#   export TMUX_EXEC_PREFIX='distrobox enter ubuntu -- '
#
#   # Other (e.g. ssh + podman)
#   export TMUX_EXEC_PREFIX='ssh -T user@host podman exec -it mycontainer '
#
# The prefix is prepended (unquoted) to tmux / ps / pgrep calls.
# Use ssh -T (not -t) for non-interactive commands to suppress pty warnings.
#
# This allows the local orchestrator to control a tmux session on a remote
# machine and/or inside a distrobox/container without changing the other scripts.
#
# Note: ps/pgrep are wrapped only for the cmd detection in list-agents.sh.
# The pids returned by remote tmux list-panes will be resolved via the same prefix.

_tmux_exec_prefix=${TMUX_EXEC_PREFIX:-}

# When a prefix is set (remote/distrobox), invoke as:
#   prefix sh -c 'thecmd "$@"' _ arg1 arg2 ...
# The -c script text contains the command name ("tmux") as a literal token,
# so the shell inside the container performs the PATH lookup (this form
# works reliably; direct exec after -- often does not).
_tmux() {
  if [[ -n "${_tmux_exec_prefix}" ]]; then
    # Build a small script with "tmux" as a command token in an if,
    # mimicking the form that worked in diagnostics (sh -c with multi-statement
    # code containing the command, so lookup happens in full container env).
    ${_tmux_exec_prefix} sh -c '
if command -v tmux >/dev/null 2>&1; then
  tmux "$@"
else
  echo "tmux not found in container PATH" >&2
  exit 127
fi
' _ "$@"
  else
    command tmux "$@"
  fi
}

_ps() {
  if [[ -n "${_tmux_exec_prefix}" ]]; then
    ${_tmux_exec_prefix} sh -c '
PS_CMD=$(command -v ps 2>/dev/null || command -v /usr/bin/ps 2>/dev/null || command -v /bin/ps 2>/dev/null || echo ps)
if command -v "$PS_CMD" >/dev/null 2>&1 || command -v ps >/dev/null 2>&1; then
  ${PS_CMD:-ps} "$@"
else
  echo "ps not found" >&2
  exit 127
fi
' _ "$@"
  else
    command ps "$@"
  fi
}

_pgrep() {
  if [[ -n "${_tmux_exec_prefix}" ]]; then
    ${_tmux_exec_prefix} sh -c '
PG_CMD=$(command -v pgrep 2>/dev/null || command -v /usr/bin/pgrep 2>/dev/null || command -v /bin/pgrep 2>/dev/null || echo pgrep)
if command -v "$PG_CMD" >/dev/null 2>&1 || command -v pgrep >/dev/null 2>&1; then
  ${PG_CMD:-pgrep} "$@"
else
  echo "pgrep not found" >&2
  exit 127
fi
' _ "$@"
  else
    command pgrep "$@"
  fi
}

# Override the commands used in the scripts so existing calls like `tmux foo`
# and `ps -p $pid` automatically use the prefix when set.
tmux() { _tmux "$@"; }
ps() { _ps "$@"; }
pgrep() { _pgrep "$@"; }
