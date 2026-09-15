# Agent instructions — checklists

A hybrid SwiftUI/UIKit iOS app (Swift 6.0, iOS 26.0+), persisted with **SwiftData**. The app
root, navigation (`NavigationStack` + `Router`), and every screen except the checklist-detail
screen are SwiftUI (`App/`, `Screens/`); `ChecklistViewController` remains UIKit, hosted via
`ChecklistScreen` (a `UIViewControllerRepresentable` with its own embedded navigation bar). Realm 20.0.5 (SPM) stays
linked for one purpose only: `LegacyRealmImporter` reads a pre-migration install's old Realm file
once, on the single launch that needs it, and never writes to it. See
[`core-docs/persistence-design.md`](core-docs/persistence-design.md) for the model, the CloudKit
constraints it was designed against, the legacy import, and sort-key ordering. **Analytics reach
Mixpanel** — Flurry was removed and replaced across a PR sequence that is now complete: the client
protocol, the locale-aware consent flow, and the Mixpanel SDK itself. A build with no configured
token, or a test run, falls back to a console client that prints in DEBUG and does nothing in
Release. See [`core-docs/analytics-spec.md`](core-docs/analytics-spec.md).

The Xcode project lives one level down at `checklists/checklists.xcodeproj`. The repo root holds
tooling, plus **`core-docs/`** — design docs that outlive any single change and are canonical for
their subject. The public support site is not here at all: it is a single static `index.html` on
the orphan `gh-pages` branch, served at <https://jimmynotjames.github.io/checklists/>.

All three targets use **file-system-synchronized folders**
(`PBXFileSystemSynchronizedRootGroup`), so `project.pbxproj` holds no per-file references. A new
`.swift` anywhere under `checklists/checklists/`, `checklists/checklistsTests/`, or
`checklists/checklistsUITests/` is compiled into that target as soon as it exists — just create the file; there is nothing to register, and adding
one produces no project-file diff. Each folder carries one membership exception, its `Info.plist`,
which is consumed via `INFOPLIST_FILE` rather than copied as a resource. To exclude some other file
from a target, uncheck it in Xcode's File inspector, which extends that exception set. The project
is `objectVersion = 100` (Xcode 26 format) and requires Xcode 26+ to open; CI pins 26.6.

Tooling here was ported from the `budgets1` repo and deliberately trimmed — see
"Deviations from budgets1" at the bottom for what was changed and why.

After a fresh clone, use [`core-docs/secrets-list.md`](core-docs/secrets-list.md) to restore the
gitignored Mixpanel and App Store Connect credentials without exposing their contents.

## Build and test

```bash
make gate        # format-changed -> lint-changed -> build. The gate. Logs to tmp/gate.log.
make build       # compile only
make test-unit   # OPT-IN — not part of the gate
make test-ui     # OPT-IN — requires a prior `make test-unit` (simulator warm-up)
```

`make system` installs the toolchain (lefthook, swiftlint, swiftformat, gitleaks) and the
git hooks. Run it once per clone.

**Tests are not in the gate, but both suites compile and pass.** `checklistsTests` links
`RealmSwift` (for `LegacyRealmImporterTests`'s fixtures) and `SwiftData`, and sets
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (mirroring the app target).

- **Unit tests are Swift Testing** — `@Suite` / `@Test` / `#expect`, structs with no base class and
  **no isolation annotations**: the target default already isolates them to the main actor, which is
  what the SwiftData and UIKit code under test needs. Don't write new ones in XCTest.
- **Per-test fixtures come from `Helpers/TestScope.swift`**, not `setUp`/`tearDown` — a struct has no
  `deinit` to tear down in. `withTemporaryDirectory` and `withIsolatedDefaults` hand the fixture to
  the test and clean up in `defer`. `TestModelContainer.makeContext()` is the shared in-memory stack.
- **`checklistsUITests` is XCTest and stays that way** — Swift Testing has no `XCUIApplication`
  equivalent, so a UI test bundle has no alternative. `budgets1` keeps its UI bundle on XCTest too.

**Don't record test counts or test-class inventories here** — they go stale on every
test-adding PR, and a wrong number in the docs is worse than no number. For the current
counts, run the suites and read the result bundle (see below).

**Don't record history here either.** This file is what to do now, so cite an issue or PR only when
it still changes someone's behaviour: an open hazard, or a decision that would otherwise get quietly
reverted (`#154` below is the example — it exists to stop the MainActor default being "cleaned up"
again). Provenance for a change that is already done belongs in `git blame` and the PR, not here; a
resolved blocker should be deleted rather than narrated as resolved.

### Reading a test result

**Never pipe a test command into `tail`/`head`/`grep` and then trust the exit code.** A shell
pipeline reports the *last* command's status, so `make test-unit 2>&1 | tail -20` exits 0 even when
the suite fails. `make test-unit` and `make test-ui` do propagate failure correctly on their own
(both scripts `set -euo pipefail`, and `xcodebuild test` is the terminal command) — verified by
breaking a test deliberately: unpiped, `make test-unit` exits 2. The exit code is only ever wrong
when a pipe throws it away.

Either drop the pipe and redirect instead (`make test-unit > tmp/test.log 2>&1; echo $?`), or read
the counts out of the result bundle, which is authoritative either way:

```bash
R=$(ls -td .build/sim/results/*-unit.xcresult | head -1)
xcrun xcresulttool get test-results summary --path "$R"
```

Look at `result` / `passedTests` / `failedTests`. Do not read pass/fail from `tmp/gate.log` or a
piped console tail — a stale log from an earlier run reads as a pass. For failure detail, swap
`summary` for `tests` and walk the nodes for `"result": "Failed"`.

All of `checklistsTests` runs against disposable in-memory `ModelContainer`s (see
`checklistsTests/Helpers/TestModelContainer.swift`), except `LegacyRealmImporterTests` and
`TwoDeviceUnionTests`, which write real Realm fixture files into a temporary directory scoped to
the test by `Helpers/TestScope.swift` and removed when that scope exits. Neither touches the
simulator's real on-disk store, so running the suite has no lasting effect on the app's data — a
deliberate break from the Realm-era `DataModelTests`, which asserted against the persisted store
and wiped it in `setUp`.

### The arm64 pin is now just a speed choice

`scripts/build.sh` and `.github/workflows/ci.yml` pass `ARCHS=arm64 ONLY_ACTIVE_ARCH=NO`. This
**used to be load-bearing** — the vendored Flurry static archive's x86_64 slice was malformed and
the linker rejected it outright, so an unpinned build simply failed. Flurry is gone and that
constraint is gone with it: an unpinned build now links clean for both slices (verified with
`lipo -info` on the built binary → `x86_64 arm64`).

The pin remains only because both of those call sites use a *generic* simulator destination, so
dropping it builds both slices — compiling Realm's large C++ tree (realm-core, s2geometry) twice
for no benefit on hardware that is always Apple Silicon. Measured on an M4 with clean
DerivedData: **56 s pinned vs 93 s unpinned** — a ~37 s saving, not a halving, since the two
slices share driver startup, SPM resolution, and asset-catalog work.

The test scripts no longer pass it at all. The net result is unchanged — they still build a single
arm64 slice — but the mechanism is worth stating precisely, because it is not the destination:
`ONLY_ACTIVE_ARCH = YES` is set in the **project-level Debug configuration** (the only place that
setting appears anywhere; Release has none and so defaults to `NO`), and test actions run Debug.
The removed pair was therefore not inert — `ONLY_ACTIVE_ARCH=NO` was widening the build and
`ARCHS=arm64` was cancelling it straight back out.

**Consequence to know about:** if anyone ever adds `-configuration Release` to `scripts/test-unit.sh`
or `scripts/test-ui.sh`, that build starts compiling both slices and gets noticeably slower, with
nothing in either script left to explain why.

**This project can be built for an x86_64 simulator again** — drop `ARCHS=arm64` from
`scripts/build.sh` and keep `ONLY_ACTIVE_ARCH=NO`, which is what forces both slices to build.

## Lint policy: changed files only

The tree carries **~96 pre-existing SwiftLint violations** (28 `force_cast`, 11 `line_length`,
11 `empty_count`, …) and 30 of 31 files need reformatting. So:

- **pre-commit** formats and strict-lints `{staged_files}` only.
- **`make gate`** formats and strict-lints only the Swift files changed vs `main`
  (`scripts/changed-swift-files.sh`).
- **`make format` / `make lint`** are repo-wide and are *manual escape hatches only*. Do not
  wire them into a gate or a hook without a plan for the resulting 30-file diff.

Code is brought up to standard as it is touched. There is no vendored third-party source in
the tree any more — the Flurry SDK was the only one, so the lint and format configs carry no
exclusions beyond build scratch.

## Commit and PR style

Shared skills are canonical under `.claude/skills/`; `.agents/skills/` contains
relative symlinks for Codex discovery. Edit the canonical files, never create
independent copies.

**Route branch → commit → PR → merge through the skills — don't hand-roll the pipeline.** The
skills are the canonical step-by-step spec (review, cross-cutting audit, gate, PR body, branch
cleanup, issue linkage); this section holds the conventions they cite:

- **Code already written, no issue:** `/create-pr`, then `/merge-pr <PR>`.
- **Issue → PR:** `/create-pr-for-issue <N>`, then `/merge-pr <PR>`.

Route all fastlane commands through the App Store skills as well, including read-only diagnostics
and archive-only validation. Use `appstore-push-testflight-build` for diagnostics, local archive
validation, and ordinary TestFlight builds; `appstore-push-release-build` for a versioned candidate;
`appstore-push-metadata` for listing publication; and `appstore-prepare-for-release` for the
resumable release workflow. Publishing skills open their PR through `/create-pr` and stop; a later
turn may use `/merge-pr`. Never run an upload lane merely to test release infrastructure.

Use `appstore-generate-screenshot-seeding` for screenshot fixture changes and
`appstore-generate-push-screenshots` for local capture, read-only screenshot inspection,
and explicitly requested screenshot publication. Refreshing screenshots reuses the approved
catalog; it does not regenerate content or authorize an upload.

**Never merge on the same turn the PR is opened.** The PR exists to be read.

### Conventions

These govern *every* commit, including ad-hoc ones not run through a skill:

- **Never push to `main`.** Branch first: `git checkout -b u/jimmyho/<tool>/<kebab-description>`
  **before the first `git add`** — moving a commit off `main` afterwards needs a destructive
  force-push. `<tool>` documents authorship (`claude-code`, `cursor`, `cursor+claude`; omit for
  manual branches). Description is lowercase kebab-case, no underscores. Enforced by the `pre-push`
  lefthook, the bash-hygiene guard (rule 4), and server-side branch protection.
- **Commit/PR subject:** `<Past-tense verb> <description>.` — sentence case, ends with a period,
  **≤72 chars**, no conventional-commit prefix (`feat:`/`fix:`/`chore:`). Match the verb's weight to
  the change (`Implemented` a feature, not `Updated`). The PR number `(#N)` goes at the end of the
  commit subject on merge.
- **Commit body:** optional for one-liners; required when a change spans more than one area. Use
  `*` bullets naming **areas of change** (feature/refactor, not files), a one-sentence `Why:` the
  diff can't show, and the `Co-Authored-By:` footer on Claude commits.
- **Write commit messages and PR bodies to a file with the Write tool**, then reference the file:
  `tmp/commit-msg.txt` → `git commit -F tmp/commit-msg.txt`, and `tmp/pr-body.md` →
  `gh pr create --body-file tmp/pr-body.md`. **Never** `printf '...' > tmp/msg && git commit -F ...`
  or an inline `--body`. *Why:* a compound Bash command is matched against the allowlist by its
  leading token, so `printf`/`echo` prompts even though the `git`/`gh` half is allowed — and heredocs
  are unreliable when the text contains quotes, backticks, or `$`. Writing the file separately keeps
  the git/gh call a standalone, already-allowed string.
- **PR body structure** follows `.github/pull_request_template.md`. Linkage: `Closes #N` (complete
  fix, auto-closes on squash-merge), `Refs #N` plus a pending note (partial), or omit entirely.
- **Squash-merge only** — one PR = one commit on `main`.

### What gates a merge

`main` has branch protection (PRs required, force-push blocked) but **zero required status checks
and zero required approvals**, and `.github/workflows/ci.yml` is disabled — so nothing server-side
stops a broken merge. `/merge-pr` compensates by running `make gate` on the PR branch and refusing
to merge unless it passes. **If CI is ever enabled, `/merge-pr` should wait on `gh pr checks`
instead, keeping the local gate as a fallback.**

## Concurrency

All three targets set `SWIFT_APPROACHABLE_CONCURRENCY = YES`; the app and `checklistsTests` also
set `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode 26's app-target defaults).
[#154](https://github.com/jimmynotjames/checklists/issues/154) records why the MainActor default
stays and what was weighed against it.

- **Types holding only constants or pure functions get `nonisolated` on the type, up front** — one
  annotation covers the type, and declaring it early beats discovering the opt-out one compile
  error at a time. See `AnalyticsEvent` in `Analytics/AnalyticsNames.swift`, `ConsentJurisdiction`.
- **Keep explicit `@MainActor`** where it documents a real constraint (`PersistenceController`,
  `AppAnalytics`), even though the default already implies it.
- **Never add the isolation default to `checklistsUITests`** — tried and reverted in #154. A
  main-actor-isolated `XCTestCase` subclass conflicts with `XCTestCase`'s own nonisolated
  designated initializers, and `init(invocation:)` can't even be overridden to fix that because
  `NSInvocation` is unavailable in Swift on this platform. A separate process driving the app
  shares no isolation domain with it anyway. The unit target sidesteps all of this by being Swift
  Testing — its suites are structs with no base class to collide with.

## Bash command hygiene

Enforced deterministically by `scripts/hooks/guard_bash_hygiene.sh`
(a `PreToolUse(Bash)` hook registered in `.claude/settings.json`). Violations are denied
with an explanation, so following these avoids both prompts and denials:

1. **No absolute `/tmp/`.** Use the project-local, gitignored `tmp/`.
2. **No `sed -i`.** Use the Edit/Write tools — `sed -i` is non-portable and bypasses file-state tracking.
3. **No `sed -n RANGE_p`** to slice files. Use Read with `offset`/`limit`.
4. **Never push directly to `main`.** Branch as `u/jimmyho/<tool>/<short-kebab-description>`
   and open a PR. `main` also has server-side branch protection.
5. **Never destroy simulators machine-wide** — see below.
6. **No `nohup`.** Use the Bash tool's `run_in_background: true`.

## What NOT to do

- **Never** `pkill Simulator`, `killall Simulator`, `simctl shutdown/erase/delete all`, or
  `simctl delete unavailable`. These hit *every* simulator on the machine, including other
  repos' and Xcode's own. Use `make sim-shutdown` / `make sim-clean`, which act only on the
  UDID in `.build/sim/device.udid`.
- Don't add `make format`/`make lint` (repo-wide) to any hook or gate. See the lint policy.
- Don't build a one-off container or router in a `#Preview`. Use `Utils/PreviewSupport.swift`
  and `.previewEnvironment()`.
- Don't hardcode an analytics token in source. Tokens come from `config/Secrets.local.xcconfig`
  via Info.plist — see [`core-docs/analytics-spec.md`](core-docs/analytics-spec.md) §10. The Flurry
  key sat in source for six years and gitleaks never caught it.
- **Ignore the local `swiftui_2024` branch entirely** — don't investigate it, diff against it, or
  flag it as context for unrelated work, even in passing. It's an unmerged, in-progress
  UIKit→SwiftUI migration; spending tokens exploring it is wasted unless the user explicitly asks
  about it by name.

## Simulator sandbox

Each clone gets its own simulator, named `iPhone 17 [<8-char hash of the repo path>]`, so no
two clones — and no other repo — ever share a device. Managed automatically by
`scripts/_sim_sandbox.sh` (sourced via `scripts/_destination.sh` by the test scripts only;
`make build` uses a generic destination and never boots a simulator).

Overrides: `SIMULATOR_NAME` picks a different base device; `SIMULATOR_UDID` pins a specific
device and skips sandbox management entirely.

## Known issues

- **UI tests fail en masse when the simulator's software keyboard is off.** `scripts/_sim_sandbox.sh`
  now self-heals this automatically on every `make test-unit` / `make test-ui` run — it checks the
  `ConnectHardwareKeyboard` preference for this repo's sandboxed UDID before reuse, and re-applies
  the fix below (cycle + `open -a Simulator`) if it's wrong. This does **not** run when
  `SIMULATOR_UDID` is set — that env var skips sandbox management entirely, so a pinned device needs
  the manual remedy below if it hits this. Kept here for that case and for the record: every test
  that types through the on-screen keyboard fails with the same signature — XCUITest cannot reach a
  keyboard key (`Next:`, `delete`), at coordinates down in the keyboard region:

  ```
  Failed to failed to scroll to visible (by AX action) Button, {{300.7, 1121.0}, {99.0, 54.0}},
  identifier: 'Next:', label: 'next', error: Error kAXErrorCannotComplete
  performing AXAction kAXScrollToVisibleAction
  ```

  This is the simulator's "Connect Hardware Keyboard" setting suppressing the software keyboard —
  **not a code defect, and not a flake that retrying fixes.** Toggle the software keyboard on the
  device (Simulator ▸ I/O ▸ Keyboard ▸ Connect Hardware Keyboard, ⇧⌘K) and re-run. It is a
  per-device setting, so a fresh clone — which gets its own sandbox simulator, see §"Simulator
  sandbox" — can hit this the first time it runs `make test-ui`. Symptom to recognize: the failures
  are exactly the typing-dependent tests while everything else passes.

  The menu item needs a human in front of Simulator.app, which an agent session does not have. The
  equivalent from a shell, scoped to this repo's own device (**verified**: took `make test-ui` from
  6 failures to 17/17):

  ```bash
  UDID=$(cat .build/sim/device.udid); defaults write com.apple.iphonesimulator DevicePreferences -dict-add "$UDID" '{ ConnectHardwareKeyboard = 0; }'; xcrun simctl shutdown "$UDID"; xcrun simctl boot "$UDID"; open -a Simulator
  ```

  **`open -a Simulator` is not optional, and this is the part that catches people.**
  `ConnectHardwareKeyboard` is a preference belonging to *Simulator.app*, not to the device, so with
  the app closed it has no effect at all and the software keyboard never appears — the setting reads
  back correctly from `defaults`, the device is booted, and the tests still fail. Verified the hard
  way twice: identical failures with the preference set and Simulator.app closed, 17/17 with it open.
  The reboot matters too, since the preference is read at boot — the preference can read back as `0`
  with Simulator.app already running and *still* be wrong until a fresh shutdown → boot →
  `open -a Simulator` cycle.

  Note the failure count is not a reliable signal on its own: a partial pass does **not** rule this
  out. The actual rule: `typeText` forces the software keyboard up, so a test survives if it *types*
  before it *taps* a keyboard key (`Next:`, `delete`) — only tests that tap a key first fail.

  The preference persists, but anything that shuts down and re-boots the device — including the
  simulator tooling's own build/launch cycle — brings the failures back, so a run that was 17/17
  yesterday can be 11/17 today with the preference still reading `0`. This is exactly why the fix
  above is now automated in `_ensure_sim_booted` rather than left as a one-liner to remember: it
  re-checks and re-applies on every run instead of trusting that yesterday's fix still holds.

- **Analytics now reach Mixpanel.** `ChecklistsApp.makeAnalyticsClient()` selects
  `MixpanelAnalyticsClient` whenever a real token is configured and the process is not a test run;
  otherwise (a fresh clone, or `-UITests1`/`IS_TESTING`) it falls back to `ConsoleAnalyticsClient`,
  which prints in DEBUG and does nothing in Release. The event and property catalogs, the privacy
  contract, and the consent model are in
  [`core-docs/analytics-spec.md`](core-docs/analytics-spec.md) — read it before touching analytics.
- **The old Flurry API key is still in git history.** It left the working tree with the Flurry
  removal, but it is present in ~294 commits of history and **the gitleaks gate does NOT catch
  it** — the key is a bare 20-char alphanumeric with no adjacent keyword and gitleaks ships no
  Flurry-specific rule. Do not mistake a green secrets gate for this being handled. The Flurry
  account should be shut down; tracked in
  [issue #115](https://github.com/jimmynotjames/checklists/issues/115).

## CI

`.github/workflows/ci.yml` is **present but disabled** (`workflow_dispatch` only). It mirrors
the local gates (lint, secrets, large files, build) for defense-in-depth against
`--no-verify`. This is a *private* repo, so macOS runner minutes bill at 10× — that is why it
is off by default. Enabling it means uncommenting the `pull_request:`/`push:` triggers **and**
adding the jobs as required status checks in the existing branch protection.

## Deviations from budgets1

| budgets1 | here | why |
|---|---|---|
| repo-wide `swiftformat .` + `swiftlint --strict .` in gate | changed-files-only | ~96 pre-existing violations in a legacy tree |
| gate = format → lint-fix → build → **test** | build only, tests opt-in | suites are green, but the UI run costs ~5 min on a simulator |
| `build.sh` boots the per-repo simulator | generic destination, no boot | saves 30–90 s; only tests need a device |
| `SRB_SIM_MAX` sim-clone concurrency | not ported | UI suite is small and not gated |
| `--header strip` | `--header ignore` | would delete every file's authorship header |
| CI on by default (public repo, free macOS minutes) | ported but disabled | private repo, macOS bills at 10× |
| i18n gates, OpenSpec | not ported | no counterpart stack here |
| fastlane | binary, metadata, and screenshot workflows; no automated submission | screenshots enable en-US only; translation integration deferred in #161; see `fastlane/SETUP.md` |
| Mixpanel analytics | built | Flurry removed; budgets1's `docs/analytics-spec.md` and `Logging/` were the reference for the port. Deviations are recorded in [`core-docs/analytics-spec.md`](core-docs/analytics-spec.md) §16 |
