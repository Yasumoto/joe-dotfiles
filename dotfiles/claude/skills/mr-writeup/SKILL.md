---
name: mr-writeup
description: Write or refresh a commit message, MR/PR title, or MR/PR description so it is succinct, describes the changeset as it will land on the default branch, and is helpful + exciting for human reviewers. Use when drafting the commit message for an MR, when asked to "update the title + description", "make the MR succinct", or "refresh the MR", or after a rebase/rework leaves the MR text stale.
allowed-tools: Bash(git log *), Bash(git diff *), Bash(git show *), Bash(git merge-base *), Bash(glab mr view *), Bash(gh pr view *), Read, Grep, Glob
---

# MR write-up

The bar, in Joe's words: **"succinct, descriptive of the changeset as it will land on master, and helpful + exciting for human reviewers."**

The MR description becomes the squash commit on the default branch, so write it as permanent history for a reviewer who has none of your context.

## Before writing

1. Read the **final** diff against the merge base: `git diff $(git merge-base origin/<default> HEAD)`. Describe that diff, not the branch's history.
2. Read 5-10 recent merged commits by the same author, in the same area (`git log origin/<default> --author=<name> -n 10 --format='%s%n%n%b'`), and match their voice, labels, and length.
3. Collect the evidence you will cite: counts, before/after values, replayed windows, test commands and results. If a number isn't verified, leave it out.

## Title

- Format: `[area/subarea] <outcome in plain words>`, ~70 chars. Use the repo's tag convention.
- State the outcome, not the mechanism. "Reject 40 MB+ requests at the load balancer" beats "Add WAF rule"; "Page only when the gateway breaks" beats "Update alert queries".
- Imperative ("Retire…", "Stop…", "Keep…") or a present-tense statement of the new behavior ("Bot spend follows the requester token"). "X instead of Y" and "X, not Y" contrasts read well.

## Body: size it to the change

- **Trivial:** title only, or one sentence.
- **Typical:** 1-3 short paragraphs or 3-5 bullets.
- **Large or cross-system:** bold inline labels, not `##` headers. Usual labels are **How it works**, **What lands**, **Review notes**. Use domain labels when they fit (**Alerts**, **Dashboard**). Go past ~300 words only for incidents.

Shape:

1. **Open with the concrete problem and its impact, with numbers.** Example: "The 5xx alert fired 40 times last week, and none of it was the gateway." End with a one-line pivot: "This fixes both." / "Now, …".
2. **What changes.** Start each bullet with a bold noun phrase, then one or two plain sentences. Nest at most one level.
3. **Evidence** for each claim: real data, a replayed window, a live check.
4. **Review notes:** the hunks worth reading closely, any non-obvious coupling, and real prerequisites, as one line each.
5. **`Tested:`** on one line, with the command and the result.
6. **Limits or next steps** in one sentence, when there are any.

Voice: plain, confident, first-person plural. Sound excited about real impact; don't hype.

## Cut

- **The journey.** Drop "first we tried…", "after investigating…", and review-round history. Describe only the end state.
- **Rollout-after-merge or deploy runbooks.** Keep only a hard prerequisite, as one Review notes line.
- **Restated diffs.** Drop file-by-file inventories, "Coverage includes:" lists, and `## Testing` sections.
- **Header scaffolding.** No `##`/`###` on anything short of an incident.
- **Unverified numbers, and mechanism trivia** a reviewer doesn't need to judge the change.
- **Slop.** If a sentence doesn't help a reviewer decide, delete it.

## Where it goes

- **Commit message first,** so `glab mr create --fill` / `gh pr create --fill` produces the MR as-is. A multi-commit MR still gets a description of the whole landed diff.
- **Override the title or description** (`glab mr update <iid> --title … --description "$(cat file)"`) only when asked, or when a rebase/rework leaves the text describing something that no longer lands. Then also amend the commit message, so the merged commit matches.
- **Write the description to a file and pass it with `"$(cat file)"`.** Apostrophes inside `$(cat <<'EOF' …)` break bash. Afterwards, read the MR back and confirm the description matches the file.
- **Don't assign reviewers, or post heads-up comments, unless asked.** The author assigns reviewers after self-review.

## Self-check before presenting

- Could a reviewer explain what lands, and why it matters, after reading only the first paragraph?
- Does every number trace to something you ran or read?
- Is anything in it about how we got here, rather than what lands? Cut it.
- Is it shorter than your first draft? It usually should be.

## Examples (shape only)

```
[infra/gateway] Reject 40 MB+ requests at the load balancer

A batch job sent 45-51 MB request bodies. The proxy buffers several
copies of each before the upstream rejects them, so it ran out of memory
and crashlooped for ~30 minutes.

- A WAF rule on the load balancer returns 413 when Content-Length is
  40 MB or more, so oversized requests never reach a pod.
- The memory limit goes from 4Gi to 8Gi, matching what prod has run
  since the incident.

40 MB clears every real request from the last 8 days (largest 33 MB). In
staging, a 39 MB request passes and a 41 MB request gets 413. Chunked
uploads without Content-Length aren't covered; proxy-side limits come
next.
```

```
[app/scanner] Hourly canary proves a leaked key still gets caught

The soak alerts show the scanner is running, not that it still catches
anything. Now, once an hour, it sends itself a known-bad request through
the real gateway and has to catch it when the row comes back.

**How it works**
- **Real path.** The canary uses the same model and endpoint as most
  production traffic, so a parser or detector regression turns it flat.
- **Can't be borrowed.** The scanner recognizes the canary by its exact
  service identity, so forwarding the canary's name doesn't silence alerts.

**Review notes**
- The identity check and its two call sites are the hunks to read closely.

Tested: `bazel test //app/scanner/...` (8/8 pass).
```
