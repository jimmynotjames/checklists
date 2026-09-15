---
name: create-pr-for-issue
description: "Take GitHub issue #N from report to open PR: implement, fresh-eye review, cross-cutting audit, make gate, push, open with Closes #N. Does not merge."
---

# Create PR for issue

Takes GitHub issue `#<N>` from report to an open, review-ready PR. The issue number is passed when
invoking this skill.

## Progress checklist

Print this unchecked at the start; tick each step as it completes.

1. **Issue** — problem restated; intended fix clear
2. **Branch** — feature branch off latest `main`
3. **Implement** — fix landed; cross-cutting concerns satisfied
4. **Fresh-eye review** — full diff reviewed; findings fixed
5. **Gate** — `make gate` green
6. **Push & PR** — branch pushed; PR opened with `Closes #<N>` or `Refs #<N>`

## Recipe

### 1. Understand the issue

```bash
gh issue view <N>
```

Add `--comments` if the thread looks substantive. Restate the problem and your intended fix in a
sentence or two **before** touching code.

If the issue is ambiguous or you find more than one reasonable fix, surface the options and ask
before implementing rather than guessing.

### 2. Create a branch

Off the latest `main`:

```bash
git checkout main
git pull --ff-only
git checkout -b u/jimmyho/<tool>/<short-kebab-description>
```

Branch format per AGENTS.md §"Conventions".

### 3. Implement the fix

Satisfy the cross-cutting checklist **as you implement**, rather than retrofitting it later — see
the `create-pr` skill's `reference/review-and-gate.md` §"Cross-cutting concerns".

### 4. Fresh-eye code review

Stage only the issue changes and commit them using a message file in `tmp/`, following
AGENTS.md. This makes the implementation visible in the branch diff below.

Get the full branch diff:

```bash
git diff main..HEAD
```

Spawn a fresh-context review subagent with the brief in the `create-pr` skill's
`reference/review-and-gate.md` §"Reviewer brief" plus the diff above. Fix High and real-bug Medium
findings in one pass; skip Low.

### 5. Run the gate

Run `make gate` in the background and collect its exit status; re-run after fixes. Don't open the
PR until green (on failure read `tmp/gate.log`).

### 6. Push and open the PR

Commit any review or gate fixes using specific paths and a message file in `tmp/` before pushing.

```bash
git push -u origin <branch-name>
```

Write the PR body to `tmp/pr-body.md` using the available file-editing tool (never inline `--body` — see
AGENTS.md §"Commit and PR style"), following `.github/pull_request_template.md`. Issue linkage:

- **`Closes #<N>`** — complete fix (auto-closes on squash-merge)
- **`Refs #<N>`** — partial fix; note what's still pending

Body length scales with the change, but its content doesn't — **Test plan** honesty included: the
`create-pr` skill's `reference/review-and-gate.md` §"Gate and PR body".

Create the PR:

```bash
gh pr create --title "<Past-tense subject>" --body-file tmp/pr-body.md
```

PR title: past-tense verb, sentence case, ends with a period, ≤72 chars, no conventional-commit
prefix (AGENTS.md §"Commit and PR style").

Report the PR URL and a one-line summary. **Stop — do not merge.**

## Autonomy

Run all steps without prompting, except when: the issue is ambiguous; a review finding needs the
user's call; or a SwiftData model change lacks its schema/migration/test triad.

## What this skill does NOT do

- **Does not run tests** — see the `create-pr` skill's closing section.
- **Does not replace `/create-pr`.** Use `create-pr` when code is already written and no issue drives
  the work.
