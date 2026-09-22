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

Design docs in `core-docs/` are canonical for their subject — read the relevant one before touching
its area:

- `persistence-design.md` — model, CloudKit constraints, legacy import, sort keys, sync status
- `analytics-spec.md` — event and property catalogs, privacy contract, consent model
- `accessibility-spec.md` — status and conventions; update it only when a change involved accessibility work
- `localization-spec.md` — key convention, locale registry, the four translation pipelines, the gates
- `secrets-list.md` — restoring gitignored Mixpanel and App Store Connect credentials after a fresh clone

The public support site is `index.html` on the orphan `gh-pages` branch
(<https://jimmynotjames.github.io/checklists/>), not on `main`.

## Writing style

Governs docs, code comments, commit bodies, and PR bodies alike.

- **Describe the current state.** No history sections, changelogs, or revision appendices — git is
  the record. Cite an issue or PR only where it still changes behaviour.
- **No drifting numbers:** test counts, test inventories, annotation counts, dates, "since #N".
- **Point at the canonical home; don't paraphrase it.** A one-line pointer to a `core-docs/` section
  beats a restatement that falls out of date the moment that section changes.
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
make gate        # format-changed -> lint-changed -> i18n-check -> build. Logs to tmp/gate.log.
make build       # compile only (generic destination; never boots a simulator)
make i18n-check  # catalog fully translated + no unkeyed user-facing strings
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

**`make i18n-check` is the one documented exception**, and it is not a lint:
`check_translations.py` validates a single file (`Localizable.xcstrings`) and
`check_source_strings.py` enforces a repo invariant — no user-facing string reaches a view
without a catalog key. Neither scales with the diff, both finish in well under a second, and a
changed-files scope would miss exactly the case they exist for: a key that stops being
translated because some *other* file changed. `make gate` and `pre-push` both run them.

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

Full rules: `core-docs/localization-spec.md`. What bites in practice:

- **Never hand-edit `Localizable.xcstrings` or a screenshot seed.** Both are generated. Use the
  scripts in `scripts/translate_catalog/`, and `generate_seeds.py` for seeds; `make gate`
  regenerates the seeds and fails on drift, so a manual edit cannot survive anyway.
- **Clean `tmp/` between runs.** `pipeline_tmp.py clean <group>` exists because a stale
  `tmp/translate-outputs/de.json` from a previous run merges silently and you get last week's
  translation with this week's keys.
- **The per-locale notes are duplicated on purpose.** `REGIONAL_NOTES` in
  `translate_catalog/dispatch_prompts.py` and `CULTURAL_NOTES` in
  `translate_metadata/dispatch_prompts.py` are separate maps because in-app register and marketing
  register are different decisions. They are not a DRY violation to fix — but if you change the
  formality call for a locale in one, change it in the other or the app and its listing will
  address the same person two different ways.
- **Model pinning is deliberate.** Haiku for ordinary UI strings, Opus for the glossary, audits,
  App Store metadata, and `sample.*` transcreation. Do not "upgrade" or "downgrade" an agent to
  trade cost against a deadline.
- **Keys that share a screen are declared as pairs.** If a new string is only meaningful in
  contrast with a neighbour (Discard beside Cancel, Delete beside Discard), name the neighbour in
  the translator comment and add the pair to `scripts/translate_audit/distinct_pairs.py`. The
  translator sees one key at a time; the gate is what knows they meet.
- **A fan-out is one message.** Dispatch all locales in a single message with
  `run_in_background: true`, never `nohup`, and never a shell loop that blocks the session.

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
  Info.plist — `core-docs/analytics-spec.md` §10.
- Ignore the `swiftui_2024` branch (origin only) unless asked about it by name. It is an unmerged
  UIKit→SwiftUI migration; exploring it wastes tokens.

## Simulator sandbox

Each clone gets its own simulator, `iPhone 17 [<hash of repo path>]`, managed by
`scripts/_sim_sandbox.sh` (sourced via `_destination.sh` by the test scripts and by
`translation-accessibility-size-check/run.sh`). `SIMULATOR_NAME` picks a different base device;
`SIMULATOR_UDID` pins a device and skips sandbox management. `make sim-status` shows it.

### The software keyboard

The UI tests do not tap keyboard keys — `XCUIElement+Keyboard.swift` drives return and delete
through `typeText`, which needs keyboard *focus* but not a visible keyboard. `make gate` fails on
any new key tap (`scripts/check_ui_test_keyboard.py`), because the Xcode recorder generates them.

`_sim_sandbox.sh` still turns Simulator.app's "Connect Hardware Keyboard" off, for ad-hoc runs and
anything that needs the keyboard on screen. The preference is per-UDID but owned by Simulator.app,
not the device, and is read at boot — so it is written before a boot, and `open -a Simulator` is
what makes it take effect. Under `SIMULATOR_UDID` none of this runs; fix it by hand with:

```bash
UDID=$(cat .build/sim/device.udid); python3 scripts/sim_keyboard_pref.py --disable "$UDID"; xcrun simctl shutdown "$UDID"; xcrun simctl boot "$UDID"; open -a Simulator
```

**The preference does not determine the outcome, and nobody has found what does.** Setting
`ConnectHardwareKeyboard = true` and rebooting does *not* reliably hide the software keyboard: a
control test that tapped `app.keys["delete"]` under exactly that setting passed. Three separate
attempts to reproduce the original mass failure on demand all failed. So treat the preference as a
hint, not a lever, and do not trust a green run to mean the setting works.

A device also carries `AutomaticMinimizationEnabled` / `HardwareKeyboardLastSeen` in its own
`data/Library/Preferences/com.apple.keyboard.preferences.plist`, which survives reboots and is not
checked or reset by anything here. That is the next place to look, not a known answer.

This is also why the tests were changed rather than the tooling: `typeText` never queries the
keyboard's accessibility elements, so it does not matter which of these is the real mechanism.

Both paths print **`SIM-KEYBOARD-FLAKE`** so the question can later be settled from evidence rather
than argument — `guard-fired` when `_sim_sandbox.sh` cycles the simulator, `tests-failed` when
`check_keyboard_flake.py` finds a run that actually failed on a keyboard key. **If you see
`tests-failed`, say so explicitly in your report rather than treating it as known flake** — it
means something still depends on the keyboard and got past the gate check.
[#231](https://github.com/jimmynotjames/checklists/issues/231) tracks deleting this machinery once
the tag has stayed quiet.

Note the whole mechanism is on borrowed time: Xcode 27 replaces Simulator.app with Device Hub, and
there is no `com.apple.iphonesimulator` domain there.

## Known issues

- **The old Flurry API key is in ~294 commits of history** and the gitleaks gate does not catch it
  (a bare 20-char alphanumeric matches no rule). A green secrets gate does not cover it. Tracked in
  [#115](https://github.com/jimmynotjames/checklists/issues/115).

## CI

`.github/workflows/ci.yml` is present but disabled (`workflow_dispatch` only; private repo, macOS
minutes bill at 10×). Enable instructions are in the workflow header.
