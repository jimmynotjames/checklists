---
name: create-pr
description: Turn already-written code changes into a reviewed, gated, open PR. Spawns a fresh-context code-reviewer subagent for a correctness-first look at the diff, audits the AGENTS.md cross-cutting checklist (SwiftData schema migration, analytics, accessibility), fills in any gaps autonomously, runs `make gate`, commits residual fixes, pushes the branch, and opens the PR. Use when the solution is mostly done and you want to review, gate, and ship it to a PR — without involving a GitHub issue. Does NOT merge; pair with /merge-pr after review. Invoked via /create-pr.
---

# Create a PR

Turns already-written code changes into a **reviewed, gated, open PR**. The implementation is
expected to be substantially complete; this skill closes the remaining gaps (cross-cutting concerns,
review findings, gate) and gets the PR open cleanly.

**Does not merge.** The PR stays open for human review. Use `/merge-pr <PR>` after you're satisfied.

## Progress checklist

Print this unchecked at the start; tick each step as it completes.

1. **Branch** — confirm on a feature branch (create one if on `main`)
2. **Initial commit** — uncommitted changes staged and committed so the diff is reviewable
3. **Fresh-eye review** — full diff reviewed; findings processed
4. **Cross-cutting concerns** — the three-item checklist audited against the diff
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

Branch name format: `u/jimmyho/<tool>/<short-kebab-description>`, all lowercase, no underscores.
`<tool>` documents authorship (e.g. `claude-code`, `codex`, `cursor`).

**On `main` with local commits**: preserve them on a feature branch before staging more work.
Fetch `origin`, create and switch to the feature branch, then point only the local
`main` ref at the fetched `origin/main` (`git branch -f main origin/main`). The
commits remain on the feature branch, and the review/gate comparisons against
`main` now include them. Inspect divergence first; do not rewrite remote `main`.

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

Get the full branch diff:

```bash
git diff main..HEAD
```

Spawn a fresh-context review subagent (Claude: `general-purpose`; Codex/Cursor: the available subagent tool) with the diff in the prompt — a fresh context, so it has no
prior conversation history coloring the review. Brief it as:

> "You are reviewing a code diff for a **UIKit iOS app (no storyboards) written in Swift 6.0 with
> `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, persisted with SwiftData**. Deployment target is
> iOS 26.0.
> Review for:
>
> - **SwiftData save correctness** — model mutations that never reach a `saveChanges(operation:)`,
>   saves that swallow failure via `saveChangesIgnoringFailure` where the user would silently lose
>   an edit, and use of a model after it has been deleted (`isDeleted`).
> - **Relationship wiring** — `Checklist.itemsStorage` and `Item.checklist` are two sides of one
>   relationship. Setting both sides can double-add; setting neither orphans the record. App code
>   must read the `items` computed property, never `itemsStorage` directly.
> - **Ordering via `sortKey`** — SwiftData relationships are unordered, so order is data. Check
>   midpoint-insertion boundaries and that callers pass the sibling array each function's doc
>   comment asks for (with or without the element being moved).
> - **Retain cycles** — missing `[weak self]` in escaping closures; delegate properties declared
>   `strong` instead of `weak`. This codebase is delegate-heavy.
> - **New force-unwraps and force-casts introduced by this diff.** The existing tree already has
>   many; judge only what this diff adds.
> - **UITableView data-source consistency** — row/section counts vs. the model after a mutation,
>   index-path arithmetic, and reload/insert/delete calls that can desync.
> - **Main-thread UI** — UIKit calls made off the main thread.
> - Correctness bugs, architectural problems, and serious future-extensibility risks generally.
>
> Do NOT flag style issues — SwiftLint and SwiftFormat own those. For each finding: state the file
> and approximate line, describe the issue, and rate it high/medium/low. Append the full diff below."
>
> [paste the full `git diff main..HEAD` output]

Process the returned findings:

- **High** — fix now, autonomously. Only pause for user input when a finding is genuinely ambiguous
  about product intent (i.e. you cannot determine the right behavior from the surrounding code).
- **Medium** — fix real bugs and architectural issues; skip subjective preferences or refactoring
  suggestions outside the change's scope.
- **Low** — skip (style, premature optimization; not your job here).

Apply all fixes at once with the available file-editing tool. Do not re-spawn the reviewer after each fix.

### 4. Cross-cutting concerns

For each concern, read the diff to determine whether it applies. This is a code-reading check — no
user input needed unless something is genuinely ambiguous.

**SwiftData schema migration** — the one that can destroy user data or crash on launch.
Applies if: the diff touches `checklists/checklists/DataModels/Checklist.swift`,
`checklists/checklists/DataModels/Item.swift`, or `checklists/checklists/DataModels/SchemaV1.swift`.
Check: adding, removing, or renaming any property on `Checklist` or `Item` is a schema change. A
model change requires a **new `VersionedSchema`** (`SchemaV2`, alongside `SchemaV1`), a
**`MigrationStage`** added to `ChecklistsMigrationPlan.stages` (empty today because `SchemaV1` is
the first schema — see its doc comment), and a **migration test** exercising the stage. Once the
CloudKit production schema is deployed, `SchemaV1` is additionally frozen in a stronger sense:
CloudKit record types are additive-only, so a field can be added but never removed or renamed —
"remove a field" becomes "stop reading it," not a schema edit. See
`core-docs/persistence-design.md`. If a model change ships without its schema/migration/test triad,
stop and raise it — this is not something to paper over.

**Analytics events** — the Mixpanel SDK is not connected yet, so events currently reach
`ConsoleAnalyticsClient`, which prints in DEBUG and does nothing in Release. **Keep instrumenting
anyway** — the point is that the catalog is complete and correct on the day the SDK lands.

Applies if: the diff introduces a new user-initiated action that materially changes app state (a new
button, a new destructive action, a new setting).
Check: a matching `analytics.track(...)` call is present. In a SwiftUI view, read the client with
`@Environment(\.analytics)`; in `ChecklistViewController` it is the injected `analytics` property;
in the three pre-environment persistence sites it is a parameter defaulting to
`AppAnalytics.shared` (see `core-docs/analytics-spec.md` §7.3). Add the event and property names to
the `AnalyticsEvent` / `AnalyticsProperty` enums in
`checklists/checklists/Analytics/AnalyticsNames.swift` — **never a string literal**, and declare
them `nonisolated static let` so SwiftData model extensions can use them — and **add a row to the
catalog in `core-docs/analytics-spec.md` §8/§9 in the same change**. Names are flat `snake_case`,
`noun_pastTenseVerb`. Route any user-supplied string through `AnalyticsText.truncated`.

No PII: item names, item notes, and checklist notes must never be sent as raw event parameters.
The one exception is `checklist_name` on `checklist_viewed`, which is a pre-existing accepted risk
documented in `core-docs/analytics-spec.md` §4.4 — it is not a precedent for adding more user content.

**Accessibility**
Applies if: the diff adds or modifies a SwiftUI `View`, a `UIView`, or a `UIViewController`.
Check: new interactive controls have an `accessibilityLabel`; custom controls (`CheckboxButton`,
`CLButton`, `CircularPercentStatusIcon`) set appropriate `accessibilityTraits` and reflect state
(a checkbox should expose selected/unselected); no fixed frame heights that clip text at large
Dynamic Type — prefer `minHeight` over a fixed `height` on rows that contain text.

Fix any gaps you find.

### 5. Run the gate

```bash
make gate
```

Run asynchronously using the current tool’s background/session mechanism and collect its final exit status — it tees output to `tmp/gate.log`. **Do not open
the PR until the gate is green.**

`make gate` here is **format-changed → lint-changed → build**. It formats and strict-lints only the
Swift files this branch touched (not the whole tree — see AGENTS.md §"Lint policy") and then
compiles. **It does not run tests.**

If the gate fails: read `tmp/gate.log`, fix the failure, and re-run. Format and lint fixes are
auto-applied to changed files; build failures require code changes.

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

Guidelines (per AGENTS.md §"Commit and PR style"):

- **No `Closes #N`** unless there is a directly related issue — use `Refs #N` for related issues,
  omit entirely if none.
- PR title follows the subject convention: past-tense verb, sentence case, ends with a period,
  ≤72 chars, no `feat:`/`fix:`/`chore:` prefix. Examples: `"Fixed checklist reset losing item
  notes."`, `"Added sort-order persistence to the checklists list."`
- In **Test plan**, say how the change was actually verified. State accurately which automated suites were run — a plausible-sounding test plan that was never run is worse than
  "verified by hand in the simulator: <steps>".

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

- **Does not merge.** Use `/merge-pr <PR>` after you're satisfied with the review.
- **Does not run tests.** They are not part of the gate, and the UI suite costs ~5 minutes on a
  simulator. Both suites *do* run and pass since #128 (46 unit, 17 UI), so run them yourself when
  the change warrants it — layout, data-model, or persistence work especially — and report the real
  result in the Test plan. Do not claim test coverage you did not obtain.
- **Does not involve a GitHub issue.** For issue-linked work, use `/create-pr-for-issue <N>` instead.
