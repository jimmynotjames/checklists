# Review, cross-cutting, and gate reference

Shared by `create-pr` and `create-pr-for-issue`.

## Reviewer brief

Spawn a fresh-context review subagent (Claude: `general-purpose`; Codex/Cursor: the available
subagent tool) with the diff pasted after this brief:

> "You are reviewing a code diff for a **hybrid SwiftUI/UIKit iOS app written in Swift 6.0 with
> `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`**, persisted with SwiftData + CloudKit. Deployment
> target is iOS 27.2. The app root, navigation, and every screen except checklist detail are
> SwiftUI; checklist detail is `ChecklistViewController` (UIKit, table-based), hosted by
> `ChecklistScreen`. You have repository access: read and grep beyond the diff wherever a check
> below needs it.
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
> - **SwiftUI state** — state owned by the wrong view (reset on re-render, or shared when it
>   should not be), environment values read where they are not provided, and `.task`/`.onChange`
>   work that re-runs or leaks when the view's identity changes.
> - **Retain cycles** — missing `[weak self]` in escaping closures; delegate properties declared
>   `strong` instead of `weak`. The UIKit side (`ChecklistViewController` and `Views/`) is
>   delegate-heavy.
> - **New force-unwraps and force-casts introduced by this diff.** The existing tree already has
>   many; judge only what this diff adds.
> - **UITableView data-source consistency** (`ChecklistViewController`) — row/section counts vs.
>   the model after a mutation, index-path arithmetic, and reload/insert/delete calls that can
>   desync.
> - **Main-thread UI** — UIKit calls made off the main thread.
> - Correctness bugs, architectural problems, and serious future-extensibility risks generally.
>
> Then three checks on the diff as a whole. Report all three every time — as a numbered problem, or
> by name in the closing `Clean:` line. Silence on them reads as "not looked at":
>
> - **Deletable prose** — any doc or comment line here that could be deleted with no loss: text
>   restating what the code already shows, history or narration of how the change came about,
>   drift-prone numbers (counts, dates, "since #N"), or duplication of something `core-docs/`,
>   AGENTS.md, a config file, or this same file already says. Quote each line. Do not flag comments
>   that narrate a UI flow for a human reader.
> - **Stale elsewhere** — prose *outside* the diff that this diff makes false. For each behaviour,
>   symbol, UI element, or default the diff changes, grep the repo for it (name, identifier, and
>   the behaviour in plain words) and read what describes it: doc comments on its callers and
>   callees, the matching `core-docs/` section, test comments, translator `comment:` strings, and
>   AGENTS.md. Quote each passage that is now wrong, with file and line. Tag it **Risk (high)** if
>   it is in `core-docs/` or AGENTS.md (the next agent will act on it), otherwise **Cleanup**. This
>   is the check
>   most likely to find something; a diff that changes behaviour and yields nothing here should
>   say what was searched.
> - **Scope creep** — anything in this diff not required by the stated change: renames, refactors,
>   drive-by fixes, edits to files the change had no reason to touch. Name the files. Fixing prose
>   that the stale-elsewhere check found is in scope.
>
> Do NOT flag style issues — SwiftLint and SwiftFormat own those; the three checks above are not
> style.
>
> Number the problems `1.`, `2.`, … Title each one `**N. <Tag> (<rating>)** — <the defect stated as
> a claim>`, where `<Tag>` is **Bug** (wrong today, a user can hit it), **Risk** (not wrong yet;
> breaks under some future change or condition) or **Cleanup** (no behaviour change: deletable
> prose, scope creep, dead code — never style), and `<rating>` is high/medium/low. The title must
> stand alone — a reader who stops there knows what is wrong. Then, per problem: an
> `End-user impact:` line in plain product language (what someone using the app experiences, how
> bad, how often — or `None — internal only.`), then the file and approximate line and the technical
> description.
>
> A check that came back clean is not a numbered problem. Name each of the three checks that came
> back clean in one closing `Clean: …` line, plus any review area you want to record as clean. Append the full diff below."
>
> **The stated change:** [one or two sentences — what this PR was asked to do, and which files that
> should touch. `create-pr-for-issue`: summarise the issue here. The scope check has nothing to
> measure against without this, and will otherwise infer scope from the diff it is judging.]
>
> [paste the full `git diff main..HEAD` output]

Process findings by severity:

- **High** — fix now, autonomously. Only pause for user input when a finding is genuinely ambiguous
  about product intent (i.e. you cannot determine the right behavior from the surrounding code).
- **Medium** — fix real bugs and architectural issues; skip subjective preferences or refactoring
  suggestions outside the change's scope.
- **Low** — skip (style, premature optimization; not your job here).

The deletable-prose, stale-elsewhere, and scope-creep verdicts are **acted on regardless of the
rating they carry** — they are the three findings the Low rule must not swallow. Delete the prose —
`git blame` first, per AGENTS.md §"Writing style". Correct each stale passage in this PR, or delete
it if the code now says it better. Revert the out-of-scope edit, or, if the change genuinely can't
work without it, keep it and say why in the PR body. (This
does not reopen the Medium rule above: the reviewer *proposing* an adjacent refactor is still
declined; the reviewer *catching* one already in the diff is not.)

Apply all fixes at once. Do not re-spawn the reviewer after each fix.

## Cross-cutting concerns

For each concern, read the diff to determine whether it applies. This is a code-reading check — no
user input needed unless something is genuinely ambiguous.

**SwiftData schema migration** — the one that can destroy user data or crash on launch.
Applies if: the diff touches `checklists/checklists/DataModels/Checklist.swift`,
`checklists/checklists/DataModels/Item.swift`, or `checklists/checklists/DataModels/SchemaV1.swift`.
Model change ⇒ new `VersionedSchema` + `MigrationStage` (added to `ChecklistsMigrationPlan.stages`,
empty today because `SchemaV1` is the first schema — see its doc comment) + migration test.
The CloudKit production schema is deployed, so it is additive-only — see `core-docs/persistence-design.md`. Ship
without the triad ⇒ stop and raise it — this is not something to paper over.

**Analytics events** — the Mixpanel SDK is connected, so a missing `track` call is a missing
measurement, not a deferred one. `ConsoleAnalyticsClient` is only the test-run and no-token fallback.

Applies if: the diff introduces a new user-initiated action that materially changes app state (a new
button, a new destructive action, a new setting).
Check: a matching `analytics.track(...)` call is present. In a SwiftUI view, read the client with
`@Environment(\.analytics)`; in `ChecklistViewController` it is the injected `analytics` property;
in the pre-environment persistence sites it is a parameter defaulting to
`AppAnalytics.shared` (see `core-docs/analytics-spec.md` §Non-SwiftUI callers). Add the event and property names to
the `AnalyticsEvent` / `AnalyticsProperty` enums in
`checklists/checklists/Analytics/AnalyticsNames.swift` — **never a string literal**, and declare
them `nonisolated static let` so SwiftData model extensions can use them — and **add a row to the
catalog in `core-docs/analytics-spec.md` §Event catalog / §Property catalog in the same change**. Names are flat `snake_case`,
`noun_pastTenseVerb`. Route any user-supplied string through `AnalyticsText.truncated`.

No PII: item names, item notes, and checklist notes must never be sent as raw event parameters.
The one exception is `checklist_name` on `checklist_viewed`, which is a pre-existing accepted risk
documented in `core-docs/analytics-spec.md` §Free-text exception — it is not a precedent for adding more user content.

**Accessibility**
Applies if: the diff adds or modifies a SwiftUI `View`, a `UIView`, a `UIViewController`, or a
color (`Colors.xcassets`, `Colors*.swift`, or a `.tint`/`.foregroundStyle` change).
Check: new interactive controls have an `accessibilityLabel`; custom controls (`CheckboxButton`,
`CLButton`, `CircularPercentStatusIcon`) set appropriate `accessibilityTraits` and reflect state
(a checkbox should expose selected/unselected); no fixed frame heights that clip text at large
Dynamic Type — prefer `minHeight` over a fixed `height` on rows that contain text. New or changed
colors: the foreground/background pair is in `PaletteTests`, with a high-contrast value if the
default falls short, and `make test-ui` has run, since its audits check contrast and neither is in
the gate.

**Reduce Motion**
Applies if: the diff adds or changes an animation — SwiftUI `.animation`/`withAnimation`/
`.transition`, or UIKit `UIView.animate(withDuration:...)`/any `animated:` call (`setContentOffset`,
`scrollToRow`, etc. obey `animated: true` regardless of the Reduce Motion setting).
Check: gate it on Reduce Motion using the established pattern
(`@Environment(\.accessibilityReduceMotion)` in SwiftUI, `UIAccessibility.isReduceMotionEnabled` in
UIKit), or record a one-line rationale for leaving it ungated. Add the verdict to the animation
inventory in `core-docs/accessibility-spec.md` §Animation and Reduce Motion.

If the change involved any accessibility or Reduce Motion work, read `core-docs/accessibility-spec.md`
and update it in the same PR. Otherwise leave it unread.

**Localization**
Applies if: the diff adds or changes any user-facing string, the string catalog, the app's sample
data, or a screenshot seed.
Check: every new string is a dotted key with a real translator comment, read through
`String(localized:defaultValue:comment:)`; locale-invariant text uses `Text(verbatim:)`; genuinely
shared copy reuses a `common.*` key instead of adding a near-duplicate; and
`translate-new-strings` has been run so `check_translations.py` passes. A bare `Text("English")` is
a gate failure, not a review note — `check_source_strings.py` will catch it, so find it first.
Sample-data changes also need the transcreation fan-out and `generate_seeds.py`, since the
screenshot seeds derive from those keys. Never hand-edit `Localizable.xcstrings` or a seed file.
Details: `core-docs/localization-spec.md`.

**Secrets inventory**
Applies if: the diff adds, removes, or renames a gitignored secret-bearing file; introduces a new
API token, private key, credential variable, or external secret location; or changes a machine-local
credential prerequisite needed after a fresh clone.
Check: update `core-docs/secrets-list.md` in the same change with the local path, tracked template or
setup source, required variable names, restoration source, and a safe validation method. Never put
secret values in the inventory or read/print an actual secret file to verify the documentation.

Fix any gaps you find.

## Gate and PR body

Run `make gate` in the background and collect its final exit status — it tees output to
`tmp/gate.log`. **Do not open the PR until the gate is green.** What the gate does: AGENTS.md
§"Build and test". On failure, read `tmp/gate.log`, fix the failure, and re-run. Format and lint
fixes are auto-applied to changed files; build failures require code changes. A `doc-check`
failure means a pointer, symbol, or file named in prose no longer exists, or an added line
narrates history: fix the prose, never the check's allowlist, unless the name is genuinely
external to this repo.

Then check the issue references the diff adds — the gate is offline and cannot:

```bash
git diff main...HEAD | grep -E '^\+' | grep -oE '\B#[0-9]{1,5}\b' | sort -u
```

Run `gh issue view <N> --json state` for each (a PR number resolves too; skip those, and skip
test fixtures and hex colours the pattern also matches). A
reference to a closed issue in a comment or doc is history: delete it, unless the text is about
that closed item on purpose, like a PR body's `Closes #N`.

In **Test plan**, say how the change was actually verified. State accurately which automated suites
were run — a plausible-sounding test plan that was never run is worse than "verified by hand in the
simulator: <steps>".

Length scales with the change — a one-line fix gets a one-line body, a schema migration gets what it
needs. What's constrained is the *kind* of content: AGENTS.md §"Writing style", which governs PR
bodies too. The reader to write for is the agent who later mines merged PRs for the reasoning behind
a decision, and pays for every line of noise on the way to it.
