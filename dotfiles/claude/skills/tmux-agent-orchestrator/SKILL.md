---
name: tmux-agent-orchestrator
description: Turn the current agent into a conductor/orchestrator that discovers, launches, inspects, sends instructions to, monitors progress of, and coordinates multiple other AI coding agents (Claude Code, Grok Build, Hermes, etc.) running in their own dedicated tmux panes or windows. Use for swarm/parallel work, delegation of subtasks, cross-review, long-running orchestration, or managing a "team" of agents while the user is away or focused elsewhere. Trigger phrases: "orchestrate the agents", "manage the tmux swarm", "direct the other agents in tmux", "launch two more agents for X and Y then synthesize", "use the agent orchestrator".
allowed-tools: Bash(tmux *), Bash(ps *), Bash(git *), Bash(ssh *), Bash(./scripts/*), Bash(${SKILL_DIR}/scripts/*)
---

# Tmux Agent Orchestrator (Conductor Skill)

You are the **orchestrator / conductor**. Your job is to treat other AI agents running in tmux as a team of specialists you can direct, monitor, and coordinate — exactly like a human engineering manager would with a group of developers in separate terminals.

This skill works across Claude Code, Grok Build, Hermes, and similar TUIs because it operates at the tmux layer (universal).

## Core Model

- **You (orchestrator)**: Run in a control pane, the main shell, or a dedicated "conductor" window/pane. You have broad visibility and the ability to run tmux commands and helpers.
- **Specialist agents**: Run in their own panes or windows. Each has its own context window, persona/role, and working directory. They do the heavy lifting on assigned subtasks.
- **Shared artifacts**: Use a "preview" pane (or dedicated window) for documents, diffs, designs, etc. Agents (and you) can push files there for the team to see.
- **State**: You maintain a live mental model (and optional small state file) of the current "orchestra": which pane/window is which role + current task + status.

## Setup & Conventions (One-Time or Per Session)

The ideal layout (evolved from earlier multi-agent planning; current implementation prefers stable window names + roster state):

- Multiple agent panes/windows (e.g. 2x2 grid or separate windows named `agent-research`, `agent-impl`, `agent-review`).
- One shared preview pane/window that agents and you can target for output.
- Optional "status" or kanban pane.

**Friendly naming (strongly recommended) + stable labels for dynamic TUIs:**

Grok Build, Claude Code, and similar TUIs frequently overwrite *pane titles* with live status ("⠼ - Running: ...", "Thinking - ", prompt prefixes, " - grok"). This makes bare `select-pane -T` labels fragile.

**Prefer window names** (they appear in the tmux status bar as "8: voice-orchestrator" and are stable):

```bash
# From inside the pane you want to label (best: use the helper)
./scripts/set-label.sh agent-research
# or manually
tmux rename-window "agent-impl"
tmux select-pane -T "agent-impl"   # title is secondary / for humans
```

The `list-agents.sh` script now:
- Prefers window names for the FRIENDLY column (cleaned of noise).
- Marks the pane running the list with `@` and "(orchestrator)" / "(self)".
- Cleans common TUI pollution so "voice-orchestrator (orchestrator)" shows cleanly even mid-command.

Target syntax the helpers understand (more robust now):
- By (window) name or substring: `agent-research`, `voice-orchestrator`, `drift`
- By pane id: `%143`
- By window spec: `8:voice-orchestrator` or just the window name
- "preview" for the shared preview target

Run `./scripts/set-label.sh <name>` *from inside any pane* (including specialists) to give it a stable identity the conductor can target reliably. Launching via `launch-agent.sh` will suggest this for split-pane agents.

**Launch convention for new agents (in a fresh pane):**

```bash
# Inside the new pane, after cd
claude --dangerously-skip-permissions
# or
grok
# or hermes (or the appropriate launch for your Hermes TUI/gateway)
```

Tell new agents their role + the preview target in the first message you send them.

## Helper Scripts (Use These)

All helpers live next to this SKILL.md in `scripts/`. Invoke them with the full skill-relative path or `./scripts/...` when your cwd makes sense. They are designed to be robust and to output machine-friendly + human-readable results.

- `scripts/list-agents.sh` — Discover running agents. Outputs a table with stable friendly name (prefers window names, cleans TUI noise like "Running:..." and spinners), pane_id, window, dir, status, cmd. Marks @ for the current/self pane and (orchestrator). Run this first in almost every turn.
- `scripts/capture-agent.sh <target> [lines]` — Clean recent output from a pane (last N lines by default 60). Strips common noise (prompts, ANSI if possible, very long tool dumps). Use before deciding what to do next with an agent.
- `scripts/send-to-agent.sh <target> "message here" [--no-execute] [--force]` — The primary way to direct another agent. Sends the text as if the user typed it at their prompt and hits Enter (unless --no-execute). Handles multi-line and quoting. Always prefer high-level instructions over raw keystrokes. Resolution prefers stable window names. **Safety**: refuses by default unless the target looks like an active agent TUI (grok/claude/hermes in title etc.); use `list-agents.sh` first to verify. `--force` overrides (use with care for plain shells).
- `scripts/launch-agent.sh <friendly-name> [role-description] [working-dir] [--window|--split]` — Creates a new pane (or window), sets labels, cds, launches a fresh agent TUI, optionally sends initial role (with labeling advice appended for split cases). Returns target info.
- `scripts/set-label.sh <name>` — Run *from inside a pane* to set both its pane title and (stable) window name. This is the primary tool for giving agents/orchestrator reliable identities when using Grok/Claude etc.
- `scripts/preview-push.sh <path>` — (If a preview target is configured) Pushes a file to the shared preview pane using your preview convention (e.g. glow for .md). Agents can be told to do the same.
- `scripts/roster.sh` — Central persistent state (JSON roster in `~/.config/tmux-agent-orchestrator/roster.json`). Subcommands: list, get, set, update, mark, remove. Use this as the single source of truth for who is doing what.
- `scripts/wait-for-agent.sh <target> [--timeout 300] [--pattern "DONE"]` — Low-level building block: block until the target reports a completion signal (polls via capture-agent).
- `scripts/flow_delegate.sh <name> "task..." [--role ...] [--new] [--wait] [--notify]` — Higher-order delegation flow (prefixed `flow_` per project convention for multi-command orchestration). Composes roster + launch + labeling + scoped send + optional wait + roster update. The recommended way to hand off substantial work.
- `scripts/conductor-status.sh` — Quick "what is my orchestra doing?" (roster + live list-agents summary). Run this often from the conductor pane.
- `scripts/transcript.sh <target> [--summary|--grep PATTERN|--last-turns N|--file F|--raw] [--cwd PATH]` — Access the full on-disk session transcript for a pane (Grok chat_history.jsonl, summary.json, etc.). This is the reliable way to recover deep context after compaction, when tmux scrollback has been eaten by TUI noise, or when capture-agent.sh returns almost nothing. Resolves the same way as the other helpers (or pass --cwd directly for testing/direct paths). Claude panes get metadata only (full history not exposed the same way). Add the AGENT_PROGRESS.md convention to delegations so specialists maintain an explicit artifact the conductor can just `cat`.

**Layers**: Low-level scripts (roster, wait-for, list-agents, send-to, etc.) are the direct building blocks. Higher-order flows that combine several steps use the `flow_` prefix when it improves clarity and reduces repetition for common patterns.

Examples the orchestrator should use:

```bash
# Inventory
./scripts/list-agents.sh

# See what the research agent is doing
./scripts/capture-agent.sh agent-research 80

# Give it a clear subtask
./scripts/send-to-agent.sh agent-research "Focus only on the auth flow in src/auth/. Read the relevant files, identify the three biggest risks with the current token handling, and report back with concrete recommendations and code pointers. When done, say DONE and nothing else."

# Launch a fresh reviewer
TARGET=$(./scripts/launch-agent.sh agent-reviewer "You are a meticulous senior code reviewer. Your only job is to find bugs, security issues, and style violations.")
./scripts/send-to-agent.sh agent-reviewer "Review the changes the impl agent just made. Use the preview pane for any large outputs."

# Label the current pane (or tell a specialist to do so inside theirs for stable targeting)
./scripts/set-label.sh voice-orchestrator

# Shared context
./scripts/preview-push.sh docs/design.md
```

The scripts are intentionally small and auditable. Read them with `cat ${SKILL_DIR}/scripts/NAME.sh` when you need to understand or debug behavior.

## State, Roster & Delegation Layers

The skill is built in explicit layers so the conductor can work at the right level of abstraction:

- **Low-level building blocks** (direct, composable):
  - `roster.sh` — persistent shared state
  - `list-agents.sh`, `capture-agent.sh`, `send-to-agent.sh`, `set-label.sh`, `wait-for-agent.sh`, `launch-agent.sh`, `preview-push.sh`

- **Higher-order flows** (prefixed `flow_` when they orchestrate multiple steps for common patterns):
  - `flow_delegate.sh` — the primary "hand this substantial task to a specialist (new or existing)" command. It manages launch/labeling/roster/scoped-send/wait/roster-update in one invocation.

This separation keeps the primitives small while giving you (the conductor agent) obvious, reliable higher-order commands for the 80% cases. Use the building blocks when you need fine control; reach for `flow_*` for speed and consistency on repeated workflows.

Update the roster whenever you assign or complete work. It survives tmux resurrect and gives you (and any specialists you instruct) a shared picture of the current orchestra.

## Reliable long-term context (transcripts + state files)

tmux `capture-pane` (and therefore `capture-agent.sh`) is fundamentally limited: pane history is capped (often 5k lines), many TUIs (Grok, Claude) constantly emit spinners, "Thought for Xs", hook markers, and status lines that consume the buffer, and some panes report near-zero usable history after attachment or compaction. Older context (plans, decisions, the actual "3-5 bullet" items an agent delivered before saying "waiting for approval") frequently disappears.

**Use `transcript.sh` as the primary recovery tool** for any pane that has run Grok Build:

- `./scripts/transcript.sh tf-drift-solution --summary`
- `./scripts/transcript.sh agent-voice-mcp --grep "rearch|DONE"`
- `./scripts/transcript.sh %243 --last-turns 10`
- `./scripts/transcript.sh transcript-impl --file chat_history.jsonl | tail -c 200k`

It resolves the same friendly names the rest of the skill uses, walks `~/.grok/sessions/<urlencoded-cwd>/<latest-uuid>/`, and surfaces `summary.json`, clean recent turns from `chat_history.jsonl`, or raw files. Claude panes currently only yield the lightweight `~/.claude/sessions/*.json` metadata; the full history is not laid out the same way.

**Strongly encourage the state-file convention.** When you delegate (via `send-to-agent.sh` or `flow_delegate.sh`), include language like:

"Maintain a concise running summary of decisions, the current plan, status, blockers, and key artifacts in `AGENT_PROGRESS.md` (or `.agent-state.json`) at the root of your worktree. Update it after major steps or before pausing for human input. The orchestrator will read it directly with `cat`."

This gives you a durable, human- and script-readable artifact that survives everything and requires no scrollback gymnastics.

Combine all three sources in the loop: `list-agents` + `capture-agent` for the live view, `transcript.sh` when you need the real history, and `AGENT_PROGRESS.md` (or the roster) for the synthesized state the specialists have explicitly maintained for you.

## Typical Orchestration Loop (Your Primary Workflow)

1. **Inventory** — Run list-agents. Build/update your roster (who is doing what).
2. **Assess** — For key agents, capture recent output with `capture-agent.sh`. When that is thin (history eaten by TUI noise, post-compaction, or the agent is in a very long session), immediately reach for `transcript.sh` (or cat any `AGENT_PROGRESS.md` the agent was told to maintain). Look for:
   - Progress / task lists / "in progress"
   - Explicit blockers ("Do you want to proceed?", permission prompts, "waiting on user")
   - Completion signals ("DONE", "ready for review", tests passing)
   - The real earlier plan or decisions that have scrolled out of tmux
   - Drift or wrong direction
3. **Act**:
   - Send high-level, role-specific instructions to unblock or redirect.
   - Create new agents for parallel tracks when beneficial (use best-of-n thinking but with real separate context windows).
   - Route artifacts (have one agent write a file, tell another "read the output the researcher just produced in the preview pane").
   - Push useful files to the shared preview pane so the whole team sees them.
4. **Synthesize** — When specialists report back (or on a timer), capture their outputs, combine, decide next wave of work or surface to the human.
5. **Monitor long-running** — For agents left to run while you (the orchestrator) do other things or the human is away, you can set up periodic checks (similar to the older passive tmux-orchestration skill) using whatever cron/background mechanism the host agent supports, or simply remember to re-inventory on your next turn.

Always keep instructions to specialists **scoped and verifiable**. Tell them the success criteria and a clear "when you are done, output exactly: DONE - <one sentence summary>".

## Safety & Etiquette

- **Never send keys to your own orchestrator pane.**
- **send-to-agent.sh now has safety checks**: it refuses (by default) to paste long messages into panes that don't look like they have an active AI agent TUI running (no "grok|claude|hermes|agent-*" in title/window/path). This prevents the exact problem of injecting text directly into a plain bash shell (where it gets executed as commands or pollutes the prompt).
  - Always run `./scripts/list-agents.sh` first and inspect the FRIENDLY/TITLE/CMD columns to confirm the target pane is actually running the agent TUI at a prompt.
  - Use `--force` only if you are absolutely sure (e.g., deliberately sending a short shell command).
  - If a pane shows as plain `-bash` or a shell prompt in captures, launch the agent TUI there first (via launch-agent.sh or manually) before directing it.
- Prefer sending natural-language instructions over trying to drive the other agent's tools directly (the specialist agent has its own tool use).
- When an agent is blocked on a permission or yes/no prompt that the orchestrator can decide, you may send the response — but log it and prefer to ask the human for truly risky actions.
- Respect the user's current focus pane. Don't steal focus unless the user asked for a demo.
- Large context dumps: capture, synthesize, and send only the relevant excerpt to other agents or the preview.
- Long-running swarms: use the host agent's background/cron/notification features (Telegram, TTS, etc.) to alert the human or yourself when something needs attention.
- Cleanup: offer to kill finished or failed agent panes when the task is complete.
- **Passive observation by default**: For "just take a look / stay on top of things", prefer `list-agents.sh` + `capture-agent.sh`. Only send directives when you have a clear, scoped instruction and have verified the target is an agent TUI. Do not make unsolicited changes in other panes.

## Integration with Your Existing Tools

- **Wiki snapshots**: The `wiki-snapshot-tmux` script (in your dotfiles scripts) gives a great static view of the whole session. You can run it and push the result to preview or read it.
- **Existing passive monitoring**: The older `tmux-orchestration` skill in Hermes is good for remote/mobile "are they blocked?" pings. This orchestrator skill is the *active direction* counterpart. You can use both.
- **Kanban / task decomposition**: If a `kanban-orchestrator` or similar skill exists, use it to break work into assignable chunks before delegating to agent panes.
- **commit-push-open-mr** and review skills: After a specialist (or group) finishes a coherent piece of work, you can delegate the commit/MR/review phase to the appropriate specialist or do it yourself.
- **Your monorepo Claude.md / conventions**: All agents you launch should inherit the project style (Bazel, [tag] commits, glab, single spaces, etc.). Send a short "follow the project Claude.md" reminder when creating a new agent in the monorepo.

## Pane vs Window Targeting (Both Supported)

Your current muscle memory may be window-based (Ctrl-a 1, 2, ...). The multi-agent plan also explored visible pane grids.

This skill supports both:
- Target by window name or `session:window`.
- Target by pane id or title (for split layouts).

When creating new agents, `launch-agent.sh` defaults to splitting panes (visible team) but can be told `--window` for the classic multi-window style. The choice is yours per session; the helpers abstract the difference.

## Stable labeling with dynamic TUIs (Grok Build, Claude Code, Hermes, etc.)

This is the #1 source of "the orchestrator can't find the pane I just labeled" problems.

**Root cause**: Many TUIs set the pane title on every prompt/activity update (spinners + "Running: the exact command", first N chars of your query, " - grok").

**What works reliably**:
- **Window names** (`rename-window` or `set-label.sh`). These show in `tmux list-windows`, your status bar ("8: voice-orchestrator"), and are what `list-agents.sh` now prefers for FRIENDLY.
- Explicit pane IDs (`%143`) — always accurate but ugly to type.
- `set-label.sh <name>` — the helper to use from *inside* the pane you want to stabilize. It does both the window rename (affects the window containing the current pane) and the pane title.

**Workflow**:
1. Orchestrator: `./scripts/list-agents.sh`
2. For a new specialist or to (re)label self: tell it or run `./scripts/set-label.sh agent-foo` (or `voice-orchestrator`).
3. Re-inventory. The name (or substring) now works for `send-to-agent.sh`, `capture-agent.sh` etc. even if the TUI later mangles the pane title.

Launch scripts already set initial labels and (for non-window launches) suggest running `set-label.sh` to the new agent in the role prompt.

You can also do it manually from the orchestrator pane for any target:
```bash
tmux select-pane -t agent-research -T agent-research
tmux rename-window -t agent-research agent-research
```

Re-read list-agents.sh and set-label.sh for the current cleaning/resolution logic.

## Remote Hosts and Distrobox / Containers

The skill and helpers now support controlling a tmux session on a remote host and/or inside a distrobox (or similar container tool) without requiring the orchestrator to be inside that environment.

**How it works**:
- Set the environment variable `TMUX_EXEC_PREFIX` in the shell where you run the orchestrator (or the scripts directly).
- All `tmux`, `ps`, and `pgrep` invocations in the scripts will be transparently prefixed with it.
- The prefix should be set so that `prefix tmux list-panes ...` (etc.) executes the tmux command in the correct context.

**Common examples** (set before running list-agents etc.):

```bash
# Remote host only (tmux running directly on the remote)
export TMUX_EXEC_PREFIX='ssh -T user@host'

# Remote Linux box + distrobox (your exact setup)
export TMUX_EXEC_PREFIX='ssh -T joe@joe-epona.int.n7k.io distrobox enter ubuntu -- '

# Local distrobox only (orchestrator on same host)
export TMUX_EXEC_PREFIX='distrobox enter ubuntu -- '

# More complex (e.g. ssh + podman)
export TMUX_EXEC_PREFIX='ssh -T user@host podman exec -it mycontainer '
```

Use `ssh -T` (not `-t`) for non-interactive command execution to avoid pty allocation warnings.

The scripts automatically build a sh -c command line (the form that works inside distrobox) when a prefix is set.

Then use the scripts normally:

```bash
./scripts/list-agents.sh
./scripts/send-to-agent.sh agent-foo "..."
# etc.
```

The `launch-agent.sh` will create new panes/windows in the remote tmux and launch the agent command inside the target environment (make sure `grok`, `claude`, etc. are available inside the distrobox/container).

**Notes**:
- You still need working ssh keys / auth for remote.
- The ps/pgrep wrapping ensures cmd detection (for "is this a grok pane?") happens inside the correct environment.
- Pane IDs, window names, etc. are resolved in the remote tmux context.
- For the older passive monitoring, see the `tmux-orchestration` skill (good for quick remote status pings).
- Update the `allowed-tools` in the skill frontmatter if your host agent needs explicit `Bash(ssh *)` (the scripts are already allowed).

This keeps the scripts small while adding the flexibility for your linux + distrobox setup (and general remotes).

## Example Full Session (What You Should Do)

User: "Orchestrate three agents on the new feature: one researcher, one implementer focused on the backend, one reviewer. Use the preview pane for the design doc."

You (orchestrator):
1. `./scripts/list-agents.sh` (see current state) or `./scripts/conductor-status.sh` for a combined view.
2. Use the higher-order flow for delegation:
   `./scripts/flow_delegate.sh agent-researcher "Investigate the ray job OOMs on the bci cluster. Focus on the segmentation model memory profile. Push useful artifacts to the preview pane." --role researcher --new --wait --notify`
3. Similarly delegate the implementer and reviewer work (reusing or launching as needed). The flow handles labeling, roster registration, scoped instructions, and waiting for "DONE".
4. Use `./scripts/roster.sh list` or `get` at any time for the persistent view of assigned tasks and status.
5. For ad-hoc direction or when you want more control, fall back to the low-level blocks: `send-to-agent.sh`, `capture-agent.sh`, `wait-for-agent.sh`.
6. When specialists complete, synthesize (or delegate synthesis) and hand coherent changes off to commit-push / review skills. Update the roster as work progresses.
7. For long-running swarms, combine with periodic `monitor-agents.sh` (or the older passive tmux-orchestration skill) + your notification paths.

## Limitations & Future

- This is tmux + send-keys based. It is universal but "text in / text out". It does not have direct access to the other agent's internal tool state or memory unless the specialist agent surfaces it.
- Launching brand new TUIs in panes works best when the pane is fresh and the agent starts in its prompt.
- For very long autonomous runs, combine with the host agent's background task / cron features and the passive monitoring skill.
- Remote / distrobox robustness (via common.sh + TMUX_EXEC_PREFIX) is already present and will be exercised more as we move beyond local testing.
- Future polish ideas (after state/roster + delegation + UX/safety): deeper best-of-n across real panes, more `flow_*` patterns, richer ecosystem bridges (kanban auto-assignment, commit-push handoff), and optional persistent audit logs.

Update this skill and the helpers as your layout and agent mix evolve. Re-read this SKILL.md at the start of any major orchestration session.

**Related skills / plans**:
- The passive `tmux-orchestration` (Hermes) for remote status.
- Historical multi-agent plan (original vision that this skill operationalizes and extends; see scratch if needed).
- `commit-push-open-mr` and review skills for the later phases of work produced by the swarm.
- wiki snapshot tools for session state.

You are the conductor. The other panes are your orchestra. Make them play in harmony.
