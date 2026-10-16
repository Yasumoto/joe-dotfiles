# Research brief template

Copy everything below the line into `<brief dir>/YYYY-MM-DD-<slug>-research.md` and fill every `<…>`. Delete hints in `<…>` once filled. Keep the section names: `scripts/wait.sh` looks for the **Findings** placeholder and the `released` line.

---

# Research: <one-line question this settles> (write findings + citations back into this file)

**Created:** <YYYY-MM-DD>
**Status:** Ready for execution. Research only: web, x.com, vendor docs, upstream source, changelogs and issues. No code, no posting. Write the answers into **Findings** below, with citations.
**Related:**
- Parent work: <draft path, brief path, MR or ticket the caller is working on>
**Written by:** <claim-line output for the writing session>
**Claimed by:** (unclaimed)

## Why this is in the inbox

<2-4 sentences: what the caller is building or deciding, and which decision these answers feed. Name the decision, not just the topic.>

This is **research only**. Don't edit the parent work. The parent session folds your findings in.

## Current state / evidence (already established; don't redo)

- <Versions actually in use: CLI, SDK, service, OS.>
- <Facts already verified, with their source.>
- <Claims that are only inferred so far: mark them **[inferred]**.>
- <Sources that disagree, and which one we lean on.>

## Research questions

Answer each with a verdict (**Yes / No / Partly / Not documented**), a 1-3 line explanation, and citations: a URL plus a quoted line, or a source file and line at a tagged version. Mark anything you inferred rather than read as **[inferred]**.

1. **<Short label>.** <Precise question. Name the exact version, key, flag or API it concerns.>
2. **<Short label>.** <…>
3. **Prior art.** <Who else solved this, and how. What practitioners report on x.com and in upstream issues: bugs, workarounds, regressions.>

## Scope

**In scope:** web search, x.com search, vendor docs, upstream repos at tagged versions, changelogs and issue trackers for the questions above. Reading local checkouts read-only to confirm versions.

**Out of scope:**
- Editing anything except this file.
- Calling internal services, or running live experiments. Write an experiment down as a proposal instead.
- Posting anywhere (chat, issue trackers, code review).
- Making the decision. Report options and evidence; the parent session decides.

**Success criteria:**
- Every question has a verdict, a short answer and at least one citation in **Findings**.
- **Findings** opens with a 5-line **Summary for the caller**: what changes in the parent work, if anything.
- The `released` line is appended under **Claimed by**.

## What you must do when you pick this up (strict order)

1. **Claim this brief.** Replace `(unclaimed)` under **Claimed by** with the output of the line below (keep earlier claims). If another live claim is already there, stop and report it.
   ~~~sh
   printf -- '- %s · %s · %s · session %s · tmux %s\n' "$(date '+%F %H:%M %Z')" "$(hostname -s)" \
     "$(if [ -n "$CLAUDECODE" ]; then echo "Claude Code"; elif [ -n "$GROK_AGENT" ]; then echo "Grok Build"; else echo "${AGENT_HARNESS:-unknown harness}"; fi)" \
     "${CLAUDE_CODE_SESSION_ID:-${GROK_SESSION_ID:-unknown}}" \
     "$(if [ -n "$TMUX_PANE" ]; then tmux display-message -p -t "$TMUX_PANE" '#S:#I #W'; else echo none; fi)"
   ~~~
   If this file's directory is a git repo, commit it: `git -C <dir> commit -m "claim: <file name>" <file>`. Don't push; the calling session does.
2. **Read** this file, then: <parent draft or files the researcher should skim first, with the sections that matter>.
3. **Confirm the versions we actually run** (read-only): <exact commands, e.g. `tool --version`, a grep over a lockfile>. Answer for those versions where it matters.
4. **Research** each question. Prefer primary sources (vendor docs, upstream source at a tag, official issue trackers) over blogs. Use x.com search for practitioner reports and recent regressions.
5. **Write Findings** in place, under ~1,200 words. Commit if the directory is a git repo: `git -C <dir> commit -m "findings: <file name>" <file>`.
6. **Release your claim:** append `  - released YYYY-MM-DD HH:MM: done` under your claim line (or `parked: <why>`), and commit.
7. **Final message:** the 5-line summary, which answers are inferred rather than cited, and any experiment you propose.

## Gotchas

- **"Not documented" is a valid answer.** Never guess vendor internals.
- **Nothing internal leaves the machine.** No internal hostnames, emails, tokens, ticket or MR links in search queries or fetched URLs. Search generic terms.
- <Name collisions to keep apart, e.g. two products with the same name.>
- <Hosted vs self-managed differences to call out.>

## Findings

_(fill in place)_

## References

- <Primary docs to start from.>
- <Related briefs or drafts.>
