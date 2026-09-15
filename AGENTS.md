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
project-file change. Each folder's `Info.plist` is its one membership exception.

Design docs in `core-docs/` are canonical for their subject — read the relevant one before touching
its area:

- `persistence-design.md` — model, CloudKit constraints, legacy import, sort keys, sync status
- `analytics-spec.md` — event and property catalogs, privacy contract, consent model
- `accessibility-spec.md` — status and conventions; update it only when a change involved accessibility work
- `secrets-list.md` — restoring gitignored Mixpanel and App Store Connect credentials after a fresh clone

The public support site is `index.html` on the orphan `gh-pages` branch
(<https://jimmynotjames.github.io/checklists/>), not on `main`.

## Naming

Never name a repo or app by the folder it sits in on someone's machine. The sibling **codebase** is
`simple-recurring-budgets`; its **product** is **Wren** — pick by what the sentence is about. This
repo is `checklists` (`jimmynotjames/checklists`). Introduce both sibling names once per doc:
`` `simple-recurring-budgets` (the **Wren** app) ``.

## Build and test

```bash
make gate        # format-changed -> lint-changed -> build. Logs to tmp/gate.log.
make build       # compile only (generic destination; never boots a simulator)
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
- Don't record test counts, test inventories, or history in docs. Cite an issue or PR only when it
  still changes behaviour.

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
  one-sentence `Why:` the diff can't show, and `Co-Authored-By:` on Claude commits.
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
`scripts/_sim_sandbox.sh` (sourced by the test scripts only). `SIMULATOR_NAME` picks a different
base device; `SIMULATOR_UDID` pins a device and skips sandbox management. `make sim-status` shows it.

## Known issues

- **UI tests fail en masse with `kAXErrorCannotComplete` on keyboard keys** when the simulator's
  software keyboard is off (Simulator.app's "Connect Hardware Keyboard"). `_sim_sandbox.sh`
  re-checks and re-applies the fix on every test run, except under `SIMULATOR_UDID`. Manual fix for
  that case — `open -a Simulator` is required because the preference belongs to Simulator.app and
  is read at boot:

  ```bash
  UDID=$(cat .build/sim/device.udid); defaults write com.apple.iphonesimulator DevicePreferences -dict-add "$UDID" '{ ConnectHardwareKeyboard = 0; }'; xcrun simctl shutdown "$UDID"; xcrun simctl boot "$UDID"; open -a Simulator
  ```

- **The old Flurry API key is in ~294 commits of history** and the gitleaks gate does not catch it
  (a bare 20-char alphanumeric matches no rule). A green secrets gate does not cover it. Tracked in
  [#115](https://github.com/jimmynotjames/checklists/issues/115).

## CI

`.github/workflows/ci.yml` is present but disabled (`workflow_dispatch` only; private repo, macOS
minutes bill at 10×). Enable instructions are in the workflow header.
