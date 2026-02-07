---
name: commit-push-open-mr
description: Review changes, commit, push, and open or update a merge/pull request
allowed-tools: Bash
---

## Context

- Git status: !`git status`
- Current branch: !`git branch --show-current`
- Remote URL: !`git remote get-url origin`
- Staged and unstaged changes: !`git diff HEAD`
- Recent commit messages: !`git log --oneline -10`

Determine the platform from the remote URL:
- **GitLab** (e.g. `n7k.io`): use `glab` for MR operations
- **GitHub** (e.g. `github.com`): use `gh` for PR operations

## Phase 1: Review & Prepare

1. Review `git status` carefully — I may have made changes since we last looked at files. Re-read any modified files you haven't seen yet.
2. Only stage files directly relevant to our conversation that make sense as a single committable unit. Never `git add -A`.
3. Research the changes thoroughly. If you notice potential bugs, missing pieces, or improvements, **pause and point them out** so we can decide whether to address them now or move on.

## Phase 2: Commit

4. Review recent commit messages on the main branch for the relevant files/directories — match their style.
   - On GitLab repos, this typically means `[subsystem/component]` tags per the project's CLAUDE.md.
5. Write a commit message:
   - Clear title explaining the changes at a high level
   - Body focused on **why** and context — let the code describe the "how"
   - Include links to relevant documentation, conversations, or references when available
6. Attempt `git commit`.
7. If pre-commit hooks (`prek` or otherwise) report errors:
   - If the fixes are straightforward, fix and re-commit without checking with me.
   - If the errors are significant, environment-related, or suggest insufficient test coverage, **pause and let me know**.

## Phase 3: Push

8. `git push -u origin HEAD`.
9. If the push fails, run `git fetch origin` and diagnose:
   - I may have pushed from another session
   - A colleague may have pushed to the branch
   - The branch may have been rebased onto an updated base
10. **Never force-push if it would overwrite someone else's commits.** If data loss has occurred, we can recover via `git reflog`. Alert me before any force-push.

## Phase 4: Open or Update MR/PR

11. Check if an MR/PR already exists for this branch. Only create one if none exists.

**GitLab:**
- Create: `glab mr create --fill --remove-source-branch`
- Assign to `joe.smith`
- Add an agent label — your choices are `agent: claude` or `agent: grok`. Create the label if it doesn't exist, and let me know because that's a fun first!
- The first commit message populates the MR title and description. Do not manually override them unless the accumulated changes have diverged substantially.
- If updating an existing MR, check for unresolved code review feedback relevant to our changes.

**GitHub:**
- Create: `gh pr create --fill`
- The first commit message populates the PR title and description. Do not manually override them.

12. Report the MR/PR URL.
13. Ask if I'd like you to request a review by commenting `@opus, please thoroughly code review this MR. Thank you!` — and whether we should address any known concerns first.
