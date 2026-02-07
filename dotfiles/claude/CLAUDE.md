# Personal Workflow Conventions

## Git & MR Workflow

- For work repos and shared projects: Always work on a feature branch. Never push directly to main or shared branches (e.g. nlk-main).
- For personal repos where you're the primary collaborator: working directly on master is fine.
- When opening MRs, let the commit message populate the title and description automatically. Do not manually set MR title/description unless I explicitly ask.
- For commit-push-open-mr workflows: use `glab mr create --fill` to auto-populate from commits.
- Never force-push to shared branches. Only force-push to your own feature branches when necessary.
- Do not make changes I didn't ask for. No unrequested refactors, config additions, or "improvements."

## Code Review

- When reviewing MRs or diffs, only review the commits on the current branch — not the entire diff against main.
- Identify the review scope first: `git log main..HEAD --oneline` and `git diff main...HEAD`.
- If the review scope is unclear, ask which specific commits or files to review.
- Do not review the entire repository diff or unrelated changes.

## CI / Debugging

- When debugging CI failures, start by fetching actual job logs (via `glab ci trace` or API) before proposing code fixes.
- Do not propose speculative fixes without evidence from logs.
- If a first fix attempt fails, analyze why before trying again. After 2 failed attempts, stop and report findings rather than continuing to guess.

## Kubernetes / Infrastructure

- When kubectl commands fail with auth errors, tell me to re-authenticate rather than retrying repeatedly.
- Do not spend multiple attempts on expired credentials — flag it immediately.

## Languages & Conventions

- When editing shell scripts, ensure POSIX compatibility unless bash is explicitly specified in the shebang.
- Primary config languages: YAML (CI/Helm/K8s), HCL (Terraform). Validate syntax after edits.

## Planning & Approach

- Before making significant changes, state your plan in 3-5 bullet points and wait for approval.
- Do not propose fixes without first reading the relevant error logs or output.
- When investigating issues, gather evidence first (logs, metrics, file contents), then propose a fix.
