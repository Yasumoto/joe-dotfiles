---
name: briefing-review
description: Use when Joe says "let's review the briefing", "what's the plan today", "what's in the inbox", or runs /briefing-review — typically inside a claude-drive voice session on the commute. Reads today's morning briefing at ~/wiki/briefings/YYYY-MM-DD.md plus pending items in ~/claude-inbox/, and helps Joe talk through priorities for the day. Read-only — does not spawn agents, hit external auth, or mutate inbox state.
allowed-tools: Bash, Read, Glob, Grep
---

## Context

- Today: !`date +%Y-%m-%d`
- Today's briefing: !`ls -1 ~/wiki/briefings/$(date +%Y-%m-%d).md 2>/dev/null || echo "(no briefing for today — run /morning-briefing first)"`
- Recent briefings: !`ls -1t ~/wiki/briefings/*.md 2>/dev/null | head -5 || true`
- Pending inbox items: !`find ~/claude-inbox -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort | head -20 || true`

## What this skill does (and doesn't)

**Does:** read today's briefing + pending inbox items, walk Joe through them, help him decide what to tackle, defer, or dismiss. Safe to run inside `claude-drive` (voice, no permission prompts).

**Does NOT:** fan out agents, hit PagerDuty / GitLab / Grafana / k8s APIs, run device-code or any auth flow, modify inbox item status, commit anything. If Joe asks for fresh data, point him back to `/morning-briefing` in a regular Claude Code session.

## Flow

1. **Orient.** If today's briefing exists, read it fully. If not, tell Joe and offer to read the most recent one instead. Read all pending inbox items (status: pending in frontmatter).

2. **Summarize aloud in 3-4 sentences.** Urgent count, on-call state, MR review queue size, any notable trend from the dashboard scan. Match the tone of commute-driving conversation — short, declarative, no markdown in the spoken output.

3. **Walk the inbox.** For each pending item, state the title + urgency + one-line context. Ask Joe what he wants to do (tackle now / defer to X time / dismiss / leave pending). Listen — do NOT edit the files. Track Joe's verbal decisions in your working memory only.

4. **Propose a gameplan.** Based on the brief + Joe's inbox decisions, suggest a rough morning ordering: "Start with the 401 on the ingest service after standup, then the pending MR review before lunch, push the feature branch after." Ask if that works. Iterate.

5. **Wrap with explicit next actions.** The last thing Joe hears should be the 2-3 concrete things to do first when he gets to his desk. No cliffhangers.

## Tone

- Spoken, not written. If `grok-speak` is available, pipe replies through it (Joe's driving).
- Short sentences. Names over codes ("the disk-space alert" not the raw incident id).
- Don't narrate what you're doing ("I'll now read…") — just answer.
- If Joe interrupts with an unrelated question, answer it and return to the briefing flow.

## If there's nothing to review

If no briefing for today AND no pending inbox items: say so in one sentence, mention when the last briefing was, and offer to read that instead. Don't pad.
