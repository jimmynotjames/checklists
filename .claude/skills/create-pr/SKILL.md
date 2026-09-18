---
name: create-pr
description: "Review, gate, and open a PR for already-written code changes with no GitHub issue involved. Runs a fresh-eye code review, the cross-cutting audit, and make gate. Does not merge."
---

# Create a PR

Turns already-written code changes into a **reviewed, gated, open PR**. The implementation is
expected to be substantially complete; this skill closes the remaining gaps (cross-cutting concerns,
review findings, gate) and gets the PR open cleanly.

## Progress checklist

Print this unchecked at the start; tick each step as it completes.

1. **Branch** — confirm on a feature branch (create one if on `main`)
2. **Initial commit** — uncommitted changes staged and committed so the diff is reviewable
3. **Fresh-eye review** — full diff reviewed; findings processed
4. **Cross-cutting concerns** — the five-item checklist audited against the diff
5. **Gaps fixed** — review findings and any cross-cutting gaps addressed
6. **Gate** — `make gate` passes clean
7. **Commit fixes** — any post-review changes committed
8. **Push** — branch pushed to `origin`
9. **PR** — PR opened with `tmp/pr-body.md`; URL reported

## Recipe

### 1. Establish branch state

```bash
git status --short
git branch --show-current
git log --oneline main..HEAD
```

**On `main` with uncommitted changes**: create a feature branch *now*, before the first `git add`
(AGENTS.md: "Create the branch before the first `git add`"):

```bash
git checkout -b u/jimmyho/<tool>/<short-kebab-description>
```

Branch format per AGENTS.md §"Conventions".

**On `main` with local commits:** fetch origin, create the feature branch (commits come with it),
then `git branch -f main origin/main`. Never rewrite remote `main`.

**On a feature branch with no commits and no uncommitted changes**: nothing to PR. Ask for
clarification.

**On a feature branch with at least one commit or uncommitted changes**: proceed.

### 2. Commit any uncommitted changes

If `git status --short` shows uncommitted changes, stage and commit them now so the reviewer has a
clean diff to read.

Stage changes for the PR (use specific file paths, not `git add -A`):

```bash
git status --short   # identify the changed files
git add <specific-files>
```

Write the commit message to `tmp/commit-msg.txt` using the available file-editing tool — never an inline heredoc
or `printf >` (AGENTS.md §"Commit and PR style" explains why). Follow the subject/body conventions
there. Then commit:

```bash
git commit -F tmp/commit-msg.txt
```

The pre-commit hook will reformat and lint any staged Swift files; if it blocks on a `--strict`
violation, fix it and re-commit.

### 3. Fresh-eye code review

Get the full branch diff (`git diff main..HEAD`) and spawn a fresh-context review subagent with it,
using the brief in `reference/review-and-gate.md` §"Reviewer brief". Process and apply findings by
severity as described there.

### 4. Cross-cutting concerns

Audit the diff against `reference/review-and-gate.md` §"Cross-cutting concerns" (SwiftData schema
migration, analytics events, accessibility, Reduce Motion, secrets inventory) and fix any gaps you
find.

### 5. Run the gate

Follow `reference/review-and-gate.md` §"Gate and PR body" for the gate mechanics: run `make gate`,
don't open the PR until it's green, and on failure read `tmp/gate.log`, fix, and re-run.

### 6. Commit any post-review changes

If steps 3–5 produced uncommitted edits:

```bash
git diff --stat HEAD
git add <specific-files>
```

Write a commit message to `tmp/commit-msg.txt` (e.g. `Applied pre-PR review fixes.`) and commit with
`git commit -F tmp/commit-msg.txt`.

If there are no new changes after the gate, skip this step.

### 7. Push the branch

```bash
git push -u origin <branch-name>
```

The pre-push hook runs `scripts/build.sh` and blocks a push from `main`.

### 8. Open the PR

Write the PR body to `tmp/pr-body.md` using the available file-editing tool, following the structure in
`.github/pull_request_template.md` (What / Why / Test plan / Tools, then the cross-cutting checklist
marked done-or-N/A from step 4). End with the `Co-Authored-By:` footer.

PR title and issue-linkage conventions: AGENTS.md §"Commit and PR style". Test-plan honesty, and
what belongs in the body versus what to leave out: `reference/review-and-gate.md` §"Gate and PR
body".

Create the PR:

```bash
gh pr create --title "<Past-tense subject>" --body-file tmp/pr-body.md
```

Report the PR URL to the user.

## Autonomy

Run all steps without prompting, except when a review finding is genuinely ambiguous about product
intent, or when a SwiftData model change lacks its schema/migration/test triad (step 4) — that one
always gets raised.
Use the current agent’s configured permissions for gate commands, git operations, and `gh pr create`.

## What this skill does NOT do

- **Does not run tests.** They are not part of the gate, and the UI suite costs ~5 minutes on a
  simulator. Both suites run and pass, so run them yourself when the change warrants it — layout,
  data-model, or persistence work especially — and report the real result in the Test plan. Do not
  claim test coverage you did not obtain.
- **Does not involve a GitHub issue.** For issue-linked work, use `/create-pr-for-issue <N>` instead.
