---
name: create-pr-for-issue
description: Turn a GitHub issue into an open, review-ready PR. Implements the fix, runs a fresh-eye review, audits the cross-cutting checklist (SwiftData schema migration, analytics, accessibility), runs `make gate`, pushes, and opens the PR with Closes #N linkage. Does NOT merge; pair with /merge-pr after review. Invoked via /create-pr-for-issue <N>.
---

# Create PR for issue

Takes GitHub issue `#<N>` from report to an open, review-ready PR. The issue number is passed when
invoking this skill.

**Does not merge.** Report the PR URL and hand back for manual review. Use `/merge-pr <PR>` after
you're satisfied.

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

Branch name format: `u/jimmyho/<tool>/<short-kebab-description>`, all lowercase, no underscores.
`<tool>` documents authorship (e.g. `claude-code`, `codex`, `cursor`).

### 3. Implement the fix

Satisfy the cross-cutting checklist **as you implement**, rather than retrofitting it later. The
full descriptions live in the `create-pr` skill (step 4) and `.github/pull_request_template.md`:

- **SwiftData schema migration** — if you touch `Checklist.swift`, `Item.swift`, or `SchemaV1.swift`,
  remember a model change needs a new `VersionedSchema`, a `MigrationStage` in
  `ChecklistsMigrationPlan`, and a migration test — never an edit in place. Once the CloudKit
  production schema is deployed, model changes are additive only: a field can be added but never
  removed or renamed. Raise it rather than shipping it unmigrated.
- **Analytics** — the Mixpanel SDK is not connected yet, so events reach `ConsoleAnalyticsClient`
  (prints in DEBUG, silent in Release). Instrument anyway: new user-initiated state changes get an
  `analytics.track(...)` call — `@Environment(\.analytics)` in a view, the injected property in
  `ChecklistViewController`, a defaulted parameter in the persistence layer — with its names added
  to the `AnalyticsEvent`/`AnalyticsProperty` enums in `Analytics/AnalyticsNames.swift` and a row
  in `core-docs/analytics-spec.md`. No PII.
- **Accessibility** — new controls get `accessibilityLabel` and appropriate traits; nothing clips at
  large Dynamic Type.

### 4. Fresh-eye code review

Stage only the issue changes and commit them using a message file in `tmp/`, following
AGENTS.md. This makes the implementation visible in the branch diff below.

Get the full branch diff:

```bash
git diff main..HEAD
```

Spawn a fresh-context review subagent (Claude: `general-purpose`; Codex/Cursor: the available subagent tool) with the same brief as the `create-pr` skill (step 3) — the
UIKit/SwiftData/Swift 6 review criteria: save correctness, relationship wiring, sort-key ordering, retain
cycles, newly-introduced force-unwraps/casts, `UITableView` data-source consistency, and
main-thread UI. Fresh context, no prior conversation history.

Process findings by severity:

- **High** — fix now, autonomously.
- **Medium** — fix real bugs and architectural issues; skip subjective preferences outside scope.
- **Low** — skip (style, premature optimization).

Apply all fixes at once. Do not re-spawn the reviewer after each fix.

### 5. Run the gate

```bash
make gate
```

Run asynchronously using the current tool’s background/session mechanism and collect its final exit status. Re-run after any step-4 fixes. **Do not open the
PR until it's green.**

`make gate` is **format-changed → lint-changed → build** — it does not run tests. On failure: read
`tmp/gate.log`, fix, re-run.

### 6. Push and open the PR

Commit any review or gate fixes using specific paths and a message file in `tmp/` before pushing.

```bash
git push -u origin <branch-name>
```

Write the PR body to `tmp/pr-body.md` using the available file-editing tool (never inline `--body` — see
AGENTS.md §"Commit and PR style"), following `.github/pull_request_template.md`. Issue linkage:

- **`Closes #<N>`** — complete fix (auto-closes on squash-merge)
- **`Refs #<N>`** — partial fix; note what's still pending

In **Test plan**, state how the fix was actually verified. The automated suites do run and pass
since #128 (`make test-unit`, then `make test-ui`), so run whichever the fix warrants and report the
real result; where a change is only verifiable by hand, manual simulator steps are the honest
answer. Either way, write what you actually did — don't imply coverage that doesn't exist.

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

- **Does not merge.** Use `/merge-pr <PR>` after review.
- **Does not run tests** — see the `create-pr` skill's closing section.
- **Does not replace `/create-pr`.** Use `create-pr` when code is already written and no issue drives
  the work.
