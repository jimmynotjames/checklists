# Agent instructions — checklists

Hybrid SwiftUI/UIKit iOS app (Swift 6.0, iOS 26.0+), persisted with SwiftData + CloudKit. The app
root, navigation (`NavigationStack` + `Router`), and every screen except checklist detail are SwiftUI
(`App/`, `Screens/`); `ChecklistViewController` is UIKit, hosted by `ChecklistScreen`. Realm 20.0.5
stays linked only so `LegacyRealmImporter` can read a pre-migration install's Realm file once.
Analytics go to Mixpanel through the `AnalyticsClient` protocol; with no configured token, or in a
test run, `ConsoleAnalyticsClient` is used instead. Tooling was ported from
`simple-recurring-budgets` (the **Wren** app) and trimmed.

The Xcode project is `checklists/checklists.xcodeproj` (Xcode 26+; CI pins 26.6). All three targets
use file-system-synchronized folders: a new `.swift` under `checklists/checklists/`,
`checklists/checklistsTests/`, or `checklists/checklistsUITests/` compiles into that target with no
project-file change. Each folder's `Info.plist` is its one membership exception; to exclude another
file, uncheck it in Xcode's File inspector.

Design docs in `core-docs/` are canonical: read the relevant one before touching its area, instead
of re-deriving. Where a doc and the code disagree, one is a bug — say which in the PR. Docs give
rules and status, not call sites: to find where something lives, grep.

- `persistence-design.md` — persistence
- `analytics-spec.md` — analytics
- `accessibility-spec.md` — accessibility; update it only when a change involved accessibility work
- `localization-spec.md` — localization
- `secrets-list.md` — credentials

The public support site is `index.html` on the orphan `gh-pages` branch
(<https://jimmynotjames.github.io/checklists/>), not on `main`.

## Writing style

Governs docs, code comments, commit bodies, and PR bodies alike.

- **Describe the current state.** No history sections, changelogs, or revision appendices — git is
  the record. Cite an issue or PR only where it still changes behaviour.
- **No drifting numbers:** test counts, test inventories, annotation counts, dates, "since #N".
- **No speculation about future work** in comments ("for deep links later").
- **Point at the canonical home; don't paraphrase it.** A one-line pointer to a `core-docs/` section
  beats a restatement that falls out of date the moment that section changes.
- **Pointers into docs use heading names** (`persistence-design.md §Sync status`), never `§N`.
- **A callee doesn't describe its callers, and a caller doesn't restate the callee.** Keep a
  one-line pointer only where a callee's invariant is non-obvious from the call site.
- **Changing behaviour? Grep for it.** Search comments, `core-docs/`, test comments, and translator
  comments for the symbol and the behaviour it names, and fix what the change made false in the
  same PR. `make doc-check` catches dangling pointers and names; only a read catches a wrong claim.
- **Comments explain why, not what.** The Swift per-file headers stay — `.swiftformat` says why.
- **`git blame` a comment before deleting it**, and let the author decide. Human-written comments
  that narrate a UI flow stay, however redundant they look: numbered `/** 1. 2. 3. */` step lists
  above a test, `// Check that ...` lines inside one. Agent-written comments that restate a test
  name or a spec are fair game.

## Naming

Never name a repo or app by the folder it sits in on someone's machine. The sibling **codebase** is
`simple-recurring-budgets`; its **product** is **Wren** — pick by what the sentence is about. This
repo is `checklists` (`jimmynotjames/checklists`). Introduce both sibling names once per doc:
`` `simple-recurring-budgets` (the **Wren** app) ``.

## Build and test

```bash
make gate        # format-changed -> lint-changed -> i18n-check -> uitest-check -> doc-check -> build. Logs to tmp/gate.log.
make build       # compile only (generic destination; never boots a simulator)
make i18n-check  # catalog fully translated + no unkeyed user-facing strings
make doc-check   # doc pointers, headings, and named symbols resolve; no history on added lines
make test-unit   # opt-in, not in the gate
make test-ui     # opt-in; needs a prior `make test-unit` (simulator warm-up)
make system      # once per clone: toolchain + git hooks
```

`scripts/build.sh` and CI pin `ARCHS=arm64` for build speed only (Realm's C++ tree compiles once);
dropping it is safe. Don't add `-configuration Release` to the test scripts — only Debug sets
`ONLY_ACTIVE_ARCH = YES`, so Release would build both slices.

Both test suites pass. Conventions:

- Unit tests are Swift Testing (`@Suite` / `@Test` / `#expect`): structs with **no isolation
  annotations** — the target's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` already isolates them.
  Don't write new XCTest unit tests.
- Fixtures come from `Helpers/TestScope.swift` (`withTemporaryDirectory`, `withIsolatedDefaults`)
  and `TestModelContainer.makeContext()`, not `setUp`/`tearDown`.
- `checklistsUITests` is XCTest and stays so — Swift Testing has no `XCUIApplication`.

### Reading a test result

Never pipe a test command into `tail`/`head`/`grep` and trust the exit code — a pipeline reports
the last command's status. Redirect instead (`make test-unit > tmp/test.log 2>&1; echo $?`), or
read the result bundle, which is authoritative:

```bash
R=$(ls -td .build/sim/results/*-unit.xcresult | head -1)
xcrun xcresulttool get test-results summary --path "$R"   # swap summary -> tests for failure detail
```

Don't read pass/fail from `tmp/gate.log` or a stale console tail.

## Lint policy

Gate and pre-commit format and strict-lint **changed Swift files only**
(`scripts/changed-swift-files.sh`). Repo-wide `make format` / `make lint` are manual escape
hatches — never wire them into a hook or gate.

**`make i18n-check`, `make uitest-check`, and `make doc-check` are the exceptions** and run
repo-wide: a key can stop being translated, a seed go stale, or a pointer dangle because some
*other* file changed. (`doc-check`'s history-marker scan is the one part limited to added lines.)

## Commit and PR style

Skills are canonical under `.claude/skills/`; `.agents/skills/` holds relative symlinks for Codex.
Edit the canonical files only.

Route branch → commit → PR → merge through the skills; don't hand-roll the pipeline:

- Code written, no issue: `/create-pr`, then `/merge-pr <PR>` on a later turn.
- Issue → PR: `/create-pr-for-issue <N>`, then `/merge-pr <PR>`.
- All fastlane work, including read-only diagnostics and archive-only validation, goes through the
  `appstore-*` skills. Never run an upload lane to test infrastructure. Publishing skills open their
  PR via `/create-pr` and stop.

**Never merge on the turn the PR is opened.** The PR exists to be read.

### Conventions

These govern every commit, skill-driven or not:

- **Never push to `main` or `gh-pages`.** Branch `u/jimmyho/<tool>/<kebab-description>` **before the
  first `git add`** (`<tool>`: `claude-code`, `cursor`, `cursor+claude`; omit for manual branches).
  `gh-pages` is the live public site and hosts `privacy.html`: branch off it, open the PR against
  it, never retarget at `main` (the branches share no history).
- **Subject:** `<Past-tense verb> <description>.` — sentence case, trailing period, ≤72 chars, no
  `feat:`-style prefix, verb weight matching the change. `(#N)` is appended on merge.
- **Body:** optional for one-liners; otherwise `*` bullets naming areas of change (not files), a
  one-sentence `Why:` the diff can't show, a one-sentence `End-user impact:` in plain product
  language when the change is user-visible — omitted here when it isn't, unlike the PR body's
  always-present section — and `Co-Authored-By:` on Claude commits.
- **Write messages with the Write tool**, then `git commit -F tmp/commit-msg.txt` /
  `gh pr create --body-file tmp/pr-body.md`. Never inline `printf ... && git commit` or
  `--body "..."`: a compound command is matched by its leading token and prompts.
- **PR body** follows `.github/pull_request_template.md`. Link with `Closes #N` (complete fix),
  `Refs #N` (partial), or nothing.
- **Squash-merge only** — one PR, one commit on `main`.

### What gates a merge

`main` requires a PR but has zero required checks and zero required approvals, and CI is disabled,
so nothing server-side blocks a broken merge. `/merge-pr` runs `make gate` on the branch and refuses
to merge on failure. If CI is ever enabled, `/merge-pr` should wait on `gh pr checks` instead.

## Concurrency

All targets set `SWIFT_APPROACHABLE_CONCURRENCY = YES`; the app and `checklistsTests` also set
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
([#154](https://github.com/jimmynotjames/checklists/issues/154) records why it stays).

- Types holding only constants or pure functions get `nonisolated` on the type, up front
  (`AnalyticsEvent`, `ConsentJurisdiction`).
- Keep explicit `@MainActor` where it documents a real constraint (`PersistenceController`,
  `AppAnalytics`).
- Never add the isolation default to `checklistsUITests` (#154): a main-actor-isolated
  `XCTestCase` conflicts with its nonisolated designated initializers.

## Running the translation pipelines

Never hand-edit `Localizable.xcstrings` or a screenshot seed; both are generated. Everything else
that bites in practice: `localization-spec.md §Running the pipelines` and §Models are pinned
deliberately.

## Bash command hygiene

Enforced by `scripts/hooks/guard_bash_hygiene.sh` (`PreToolUse(Bash)`); violations are denied with
the fix:

1. No absolute `/tmp/` — use the gitignored `tmp/`.
2. No `sed -i` — use Edit/Write.
3. No `sed -n RANGE_p` — use Read with `offset`/`limit`.
4. Never push directly to `main` or `gh-pages`.
5. Never destroy simulators machine-wide (below).
6. No `nohup` — use the Bash tool's `run_in_background: true`.

## What NOT to do

- **Implement what was asked, and stop there.** Don't rewrite GitHub issue text, and don't rename or
  refactor beyond the change. Adjacent problems you notice get **said out loud** — in the reply or
  the turn's closing summary — and nothing more. **Never `gh issue create` without asking first**:
  "list them for later" means mention them, not file them. Which ones become issues is Jimmy's call.
- Never `pkill`/`killall Simulator`, `simctl shutdown/erase/delete all`, or
  `simctl delete unavailable` — they hit every simulator on the machine. Use `make sim-shutdown` /
  `make sim-clean`, which act only on this repo's UDID.
- Don't add repo-wide `make format` / `make lint` to a hook or gate.
- Don't build a one-off container or router in a `#Preview`; use `Utils/PreviewSupport.swift` and
  `.previewEnvironment()`.
- Don't hardcode an analytics token. Tokens come from `config/Secrets.local.xcconfig` via
  Info.plist — `analytics-spec.md §Build hygiene`.
- Ignore the `swiftui_2024` branch (origin only) unless asked about it by name. It is an unmerged
  UIKit→SwiftUI migration; exploring it wastes tokens.

## Simulator sandbox

Each clone gets its own simulator, `iPhone 17 [<hash of repo path>]`, managed by
`scripts/_sim_sandbox.sh` (sourced via `_destination.sh` by the test scripts and by
`translation-accessibility-size-check/run.sh`). `SIMULATOR_NAME` picks a different base device;
`SIMULATOR_UDID` pins a device and skips sandbox management. `make sim-status` shows it. When the
device isn't on the newest iOS runtime the selected Xcode can target (after an Xcode upgrade, say),
`scripts/sim_retire_stale.py` deletes it before use so it is recreated on that runtime; the
screenshot device gets the same treatment.

### The software keyboard

UI tests never tap keyboard keys; `make gate` fails on a new tap
(`scripts/check_ui_test_keyboard.py`). **If a run prints `SIM-KEYBOARD-FLAKE tests-failed`, say so
explicitly in your report** — never treat it as known flake. Mechanism, the `SIMULATOR_UDID`
recovery command, and #231: the `XCUIElement+Keyboard.swift` header.

## Known issues

- **The old Flurry API key is in git history** and gitleaks can't see it (a bare 20-char
  alphanumeric matches no rule), so a green secrets gate doesn't cover it.

## CI

`.github/workflows/ci.yml` is present but disabled (`workflow_dispatch` only; private repo, macOS
minutes bill at 10×). Enable instructions are in the workflow header.
