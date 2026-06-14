---
name: agent-inbox
description: Capture the current session's work into a self-contained "cold handoff" prompt written to ~/agent-inbox/. Produces a single dated markdown brief that a future agent (often an autonomous/overnight run) can execute with zero prior context.
allowed-tools: Bash(date *), Bash(ls *), Bash(git log *), Bash(git diff *), Bash(git status), Write, Read, Grep, Glob
---

## Context

- Today's date: !`date +%F`
- Inbox contents: !`ls -1t ~/agent-inbox/ 2>/dev/null | head -20`
- Current branch: !`git branch --show-current 2>/dev/null`
- Repo root: !`git rev-parse --show-toplevel 2>/dev/null`

## What this skill is for

Write out a prompt to `~/agent-inbox/`. These are **cold handoff briefs**: a future agent — frequently a fresh session or an autonomous overnight run with none of this conversation's context — must be able to open one file and execute the task safely and well. The whole value is *self-containedness*. Assume the reader knows nothing about what we just discussed.

This skill does **not** execute the task. It writes the prompt that lets someone else execute it. Deliverable = one file at `~/agent-inbox/YYYY-MM-DD-<slug>.md`.

## Process

### 1. Identify the task to capture

The task is whatever the user just pointed at; something "ready but not now." If it's ambiguous which thread the user means, ask before writing.

### 2. Gather the evidence into the file (don't make the reader re-derive it)

The best prompts are dense with concrete pointers because the picking-up agent can't see our session. Before writing, pull together:

- **Exact file paths and line numbers** for every relevant file (`path/to/file.tf:64-99`). Use Grep/Glob/Read now to confirm they're still accurate — a cold handoff with a wrong line number wastes the next agent's time.
- **Concrete observed facts**: command outputs, resource counts, error messages, API responses, ticket/MR/PR numbers, Slack thread participants. Quote real values, not "the relevant config."
- **The repo for the task, and the commit SHA(s)** (e.g. `~/src/sw` at a289d569791f9894cde8de6b09b12cfbda714bfb). This will help the incoming agent find your references even if they've been refactored/moved since.
- **External references**: doc URLs, service guides, upstream issues/PRs, dashboards.
- **Access/tooling notes**: how to auth, which kube context, which gateway URL, which tool is correct for this repo (`gh` for github.com, `glab` for the GitLab monorepo).

If there is information that could change (such as metrics or streamed logs) you should provide the command(s) to fetch the latest values.

### 3. Write the file

Filename: `~/agent-inbox/YYYY-MM-DD-<kebab-slug>.md` using today's date from context. The slug is short, specific, and topic-first.

Use this structure (drop sections that genuinely don't apply — a quick review task needs less than a complicated refactor task):

```markdown
# <Specific, scoped title — what success looks like, not just the topic>

**Created:** YYYY-MM-DD
**Status:** <Ready for execution | Open design question | Review/feedback task | Deferred until X>. <One line on what kind of handoff this is>
**Related discussion / PR / ticket:** <Slack thread + people, MR/PR links, ticket IDs>

## Why this is in the inbox

<2-4 paragraphs of motivation and context. What's the problem, why does it matter, why isn't it being done right now in this session. State plainly what kind of task this is: implementation, design-decision, or review.>

## Current state / evidence

<Everything the reader can't see. File:line pointers, command outputs, resource counts, observed behavior, the existing patterns to follow. This is the heaviest section. Be concrete.>

## Scope

**In scope:** <bullets>
**Out of scope (explicitly defer):** <bullets — name the things NOT to touch>
**Success criteria:** <how the reader knows they're done and it's safe to land>

## What you must do when you pick this up (strict order)

1. **Read everything first (no edits yet).** This file, then <key code files, with paths>.
2. **Baseline / gather evidence.** <Concrete first commands to run to confirm current reality before changing anything.>
3. **Ask any questions that will help narrow in on the correct plan and confirm your understanding.** <Leave any open questions the user may have deferred or you consider critical.>
4. **State your plan in 3-5 bullets and STOP.** Post the bullets and wait for explicit human approval before creating a branch, editing files, or running any destructive command.
5. **Only after approval:** <execution steps — branch naming, conventions, glab mr create --fill, etc.>
6. **During execution:** <re-confirm before each material step; how to test safely.>
7. **After it lands:** <retrospective note back into this inbox file or a follow-up.>

## Gotchas & additional context

<The non-obvious traps. Naming constraints, lifecycle/prevent_destroy blocks, auth differences, the "this short-circuits if the role name contains X" kind of landmine.>

## References

<URLs, docs, related inbox files, memory files.>

## Typical preferences (apply throughout)

- Simplest, most robust, idiomatic solution. No abstractions beyond what the task needs.
- Evidence-first: read logs/code/output before proposing or asserting anything.
- Plan in 3-5 bullets before any significant change; present it and wait.
- Use AskUserQuestion to confirm direction at genuine decision points and improve the plan + implementation
- Draft, don't unilaterally ship outward-facing things (posts, comments) without explicit go-ahead.
```

### 4. Confirm and report

- Write the file, then tell the user the path and give a 2-3 line summary of what it captures.
- If the task hinges on a decision that hasn't been made yet (e.g. which of several design paths), capture the full decision matrix in the file rather than forcing a choice — the picking-up agent should walk through it with AskUserQuestion.
- Don't commit or move the file anywhere; `~/agent-inbox/` is the staging ground. Don't start executing the task unless asked.

## Principles (what makes these prompts good)

- **Self-contained.** The reader has none of our context. If a fact lived only in this conversation, it must live in the file.
- **Evidence over assertion.** Real paths, real line numbers, real command output, real numbers. Verify pointers before writing them.
- **Safety gated.** Anything touching real state, prod, IAM, or outward-facing surfaces gets an explicit "plan in 3-5 bullets, then STOP for approval" gate. Make dangerous operations loud.
- **Scoped.** Say what's out of scope as clearly as what's in. Pilots stay pilots.
- **Honest about status.** "Ready for execution" vs "open design question — do not start until X is merged" are different handoffs; label them correctly.
- **Right-sized.** A review/feedback task doesn't need state-surgery ceremony. Keep the structure, scale the depth to the work.
