---
name: create-pr
description: "Review, gate, and open a PR for already-written code changes with no GitHub issue involved. Runs a fresh-eye code review, the cross-cutting audit, and make gate. Does not merge."
---

# Create a PR

Turns already-written changes into a **reviewed, gated, open PR**. The implementation is expected
to be substantially complete; this skill closes the remaining gaps and opens the PR. Branch names,
commit messages, PR titles and issue linkage follow AGENTS.md §"Commit and PR style".

## Progress checklist

Print this unchecked at the start; tick each step as it completes.

1. **Branch** — confirm on a feature branch (create one if on `main`)
2. **Initial commit** — uncommitted changes committed so the diff is reviewable
3. **Fresh-eye review** — full diff reviewed; findings processed
4. **Cross-cutting concerns** — the checklist audited against the diff
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

- **On `main` with uncommitted changes:** create the feature branch now, before the first
  `git add`: `git checkout -b u/jimmyho/<tool>/<short-kebab-description>`.
- **On `main` with local commits:** fetch origin, create the feature branch (commits come with it),
  then `git branch -f main origin/main`. Never rewrite remote `main`.
- **On a feature branch with no commits and no changes:** nothing to PR. Ask.
- **Otherwise:** proceed.

### 2. Commit any uncommitted changes

Stage specific paths (not `git add -A`), write the message to `tmp/commit-msg.txt` with the
file-editing tool, then:

```bash
git add <specific-files>
git commit -F tmp/commit-msg.txt
```

The pre-commit hook reformats and lints staged Swift files; if it blocks on a `--strict`
violation, fix it and re-commit.

### 3. Fresh-eye code review

Get the full branch diff (`git diff main..HEAD`) and spawn a fresh-context review subagent with it,
using the brief in `reference/review-and-gate.md` §"Reviewer brief". Process and apply findings by
severity as described there.

### 4. Cross-cutting concerns

Audit the diff against `reference/review-and-gate.md` §"Cross-cutting concerns" and fix any gaps.

### 5. Run the gate

Follow `reference/review-and-gate.md` §"Gate and PR body": run `make gate`, don't open the PR until
it's green, and on failure read `tmp/gate.log`, fix, and re-run.

### 6. Commit any post-review changes

If steps 3–5 produced edits, stage specific paths and commit with `git commit -F
tmp/commit-msg.txt` (e.g. `Applied pre-PR review fixes.`). Otherwise skip.

### 7. Push the branch

```bash
git push -u origin <branch-name>
```

### 8. Open the PR

Write `tmp/pr-body.md` with the file-editing tool, following `.github/pull_request_template.md`,
with the cross-cutting checklist marked done or N/A from step 4, ending with the `Co-Authored-By:`
footer. Test-plan honesty, and what belongs
in the body: `reference/review-and-gate.md` §"Gate and PR body".

```bash
gh pr create --title "<Past-tense subject>" --body-file tmp/pr-body.md
```

Report the PR URL.

## Autonomy

Run all steps without prompting, except when a review finding is genuinely ambiguous about product
intent, or when a SwiftData model change lacks its schema/migration/test triad (step 4) — that one
always gets raised.

## What this skill does NOT do

- **Does not run the app's test suites.** PR CI runs the unit suite and the three UI shards on
  every push (AGENTS.md §"Build and test"); the gate runs only the tooling tests. Run
  `make focused-tests` for tests you added or changed, and report the real result in the Test
  plan. Do not claim test coverage you did not obtain.
- **Does not involve a GitHub issue.** For issue-linked work, use `/create-pr-for-issue <N>`.
