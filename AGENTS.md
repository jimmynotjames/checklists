# Agent instructions — checklists

Hybrid SwiftUI/UIKit iOS app (Swift 6.0, iOS 27.0+), persisted with SwiftData + CloudKit. The app
root, navigation (`NavigationStack` + `Router`), and every screen except checklist detail are SwiftUI
(`App/`, `Screens/`); `ChecklistViewController` is UIKit, hosted by `ChecklistScreen`. Realm 20.0.5
stays linked only so `LegacyRealmImporter` can read a pre-migration install's Realm file once.
Analytics go to Mixpanel through the `AnalyticsClient` protocol; with no configured token, or in a
test run, `ConsoleAnalyticsClient` is used instead. Tooling was ported from
`simple-recurring-budgets` (the **Wren** app) and trimmed.

The Xcode project is `checklists/checklists.xcodeproj` (Xcode 27+; CI pins 27.1). All three targets
use file-system-synchronized folders: a new `.swift` under `checklists/checklists/`,
`checklists/checklistsTests/`, or `checklists/checklistsUITests/` compiles into that target with no
project-file change. Each folder's `Info.plist` is excluded from its target, as is the UI-test
folder's `FLAKY_TESTS.md`; to exclude another file, uncheck it in Xcode's File inspector.

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
  the record. Cite an issue or PR only where it still changes behaviour, as a bare `#N`, never a URL
  an agent would fetch.
- **No archaeology.** Never explain new code by what the same change deleted ("replaces the old
  view controller"); the comment names code that no longer exists. The one exception is a magic
  number whose only justification is history: cite its PR.
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
make gate         # tool-versions-check -> format-changed -> lint-changed -> i18n-check -> uitest-check -> doc-check -> simulator-slots-check -> test-scripts -> build -> i18n-sync-check. Logs to tmp/gate.log.
make build        # compile only (generic destination; never boots a simulator)
make i18n-check   # catalog fully translated, in Xcode's byte format + no unkeyed user-facing strings
make i18n-sync    # after `make build`: copy Swift comments/keys into the catalog, as a build in Xcode does
make doc-check    # doc pointers, headings, and named symbols resolve; no history on added lines
make test-scripts # scripts/tests (Python) + fastlane/tests (Ruby 3+; skipped with a warning if absent)
make test-unit    # opt-in, not in the gate
make test-ui      # opt-in; a one-slot run warms the device with the unit tests first if needed
make test-only ONLY=<target>/<Class>[/<test>] [ITERATIONS=3]  # one class or test, serially
make simulator-slots-status  # the machine-wide simulator pool: holders, booted devices, recent runs
make sim-udid     # this checkout's simulator UDID (boots it if needed); `make -s` for stdout alone
make sim-run      # build, install, and launch the app on this checkout's simulator
make sim-show     # open DeviceHub on this checkout's simulator
make system       # once per clone: toolchain + git hooks
```

The app's unit and UI suites are opt-in and in no gate or hook: they boot this checkout's simulator
and take minutes, while the gate never boots one. The tooling tests (`test-scripts`) are in the gate.
Give any suite run a timeout of at least 30 minutes.

`make test-ui` runs every `checklistsUITests` class except the screenshot captures that
`scripts/test-ui.sh` skips; add a new capture class to that skip list. Before a full UI run, run a
new or changed class alone with `make test-only` (§Reading a test result).

Don't add `-configuration Release` to the test scripts — only Debug sets `ONLY_ACTIVE_ARCH = YES`,
so Release would build both slices.

Both test suites pass. Conventions:

- Unit tests are Swift Testing (`@Suite` / `@Test` / `#expect`): structs with **no isolation
  annotations** — the target's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` already isolates them.
  Don't write new XCTest unit tests.
- Fixtures come from `Helpers/TestScope.swift` (`withTemporaryDirectory`, `withIsolatedDefaults`)
  and `TestModelContainer.makeContext()`, not `setUp`/`tearDown`.
- `checklistsUITests` is XCTest and stays so — Swift Testing has no `XCUIApplication`.

### Reading a test result

Never pipe a test command into `tail`/`head`/`grep` and trust the exit code — a pipeline reports
the last command's status. Redirect to a log of your own instead — another agent in this checkout
may be writing a shared one — or read the result bundle, which is authoritative. Each run prints
a `result-bundle:` line naming its own bundle; never pick the newest one in `.build/sim/results/`,
which may be another agent's:

```bash
L=tmp/test-unit-$$.log; make test-unit > "$L" 2>&1; echo "$? $L"
R=$(grep -m1 '^result-bundle: ' "$L" | cut -c16-)
xcrun xcresulttool get test-results summary --path "$R"   # swap summary -> tests for failure detail
```

Don't read pass/fail from `tmp/gate.log` or a stale console tail.

Both test scripts print one `TEST-FAILED: <test> <file:line> <text>` line per failure
(`scripts/list_test_failures.py`). A test that fails in a full run but passes an isolated rerun
(`make test-only ONLY=<target>/<Class>/<test> ITERATIONS=3`, which takes a simulator slot) is flaky: append a row to `checklists/checklistsUITests/FLAKY_TESTS.md`
with `file:line` from those lines, never a guess, name the flake in your report, and don't fix it in
passing.

Before blaming a change for new failures, run the same suite on a clean `main` for a baseline.
Several failures with one signature often point at the environment: read §Simulator sandbox first.
Keyboard failures are the exception (§The software keyboard).

## Lint policy

Gate and pre-commit format and strict-lint **changed Swift files only**
(`scripts/changed-swift-files.sh`). Repo-wide `make format` / `make lint` are manual escape
hatches — never wire them into a hook or gate.

**`make i18n-check`, `make i18n-sync-check`, `make uitest-check`, and `make doc-check` are the
exceptions** and run
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
(#154 records why it stays).

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
5. Never destroy simulators machine-wide or target `booted` (below).
6. No `nohup` — use the Bash tool's `run_in_background: true`.

## What NOT to do

- **Implement what was asked, and stop there.** Don't rewrite GitHub issue text, and don't rename or
  refactor beyond the change. Adjacent problems you notice get **said out loud** — in the reply or
  the turn's closing summary — and nothing more. **Never `gh issue create` without asking first**:
  "list them for later" means mention them, not file them. Which ones become issues is Jimmy's call.
- Never kill Simulator, DeviceHub, or CoreSimulator processes, or run `simctl shutdown/erase/delete
  all` or `simctl delete unavailable` — they hit every simulator on the machine. Use `make
  sim-shutdown` / `make sim-clean`, which act only on this checkout's devices.
- Never pass `booted` to `simctl` (`list` aside): it acts on whichever device is booted, possibly
  another checkout's. Use the UDID from `make -s sim-udid`.
- Don't add repo-wide `make format` / `make lint` to a hook or gate.
- Don't build a one-off container or router in a `#Preview`; use `Utils/PreviewSupport.swift` and
  `.previewEnvironment()`.
- Don't hardcode an analytics token. Tokens come from `config/Secrets.local.xcconfig` via
  Info.plist — `analytics-spec.md §Build hygiene`.
- Ignore the `swiftui_2024` branch (origin only) unless asked about it by name. It is an unmerged
  UIKit→SwiftUI migration; exploring it wastes tokens.
- Don't colour text or surfaces with system semantic colours (`.label`, `.secondary`, the system
  placeholder, grouped cell backgrounds). The app follows the system light/dark setting, and every
  colour comes from `Colors`, whose colorsets in `Colors.xcassets` each carry a light and a dark
  value. A new role gets its own colorset with both; iOS's grays fail 4.5:1 on the light `defaultBackground`.
- Don't delete the MoreMenuIcon32x32 image set as dead; it is kept on purpose.

## Simulator sandbox

Each checkout has its own simulator, so worktrees and clones never contend; it outlives a deleted
worktree, so run `make sim-clean` in a worktree before removing it. The device is
`iPhone 17 [<hash of the checkout's physical path>]` in the default device set, managed by
`scripts/_sim_sandbox.sh` (sourced via `_destination.sh` by the test scripts and
`translation-accessibility-size-check/run.sh`); the screenshot lane's `... Screenshots [<hash>]`
device shares the hash. `SIMULATOR_NAME` picks a different base device; `SIMULATOR_UDID` pins a
device and skips sandbox management. `make sim-status` shows the device and the lock holder;
`make sim-clean` deletes every device and parallel-testing clone carrying this checkout's hash.
When the device isn't on the newest iOS runtime the selected Xcode can target that hosts its device
type,
`scripts/sim_retire_stale.py` deletes it before use so it is recreated; the screenshot device gets
the same treatment. Once the device is up, `_sim_sandbox.sh` turns off iOS's automatic keyboard
minimization on it, which otherwise can park the software keyboard below the screen mid-run.

Agents sharing one checkout take turns: every command that touches its sandbox device (the test
scripts, `run.sh`, every `make sim-*` but `sim-status`) holds `.build/sim.lock` for its whole run;
the screenshot lane serializes on its own `capture.lock`.
A second one waits, printing who holds it, so start it with `run_in_background`; `SIM_LOCK_TIMEOUT`
(seconds) makes it give up instead. The kernel drops the lock when the holder exits, however it
exits. For parallel runs, use a worktree.

Nothing opens a window: the simulator runs headless, and `make sim-show` opens DeviceHub on it
when someone wants to watch. For anything interactive, get `UDID=$(make -s sim-udid)` and pass it
explicitly to every tool — `simctl`, an MCP server's device argument, `xcrun simctl io "$UDID"
screenshot tmp/s.png`. Device-matching tools pick the "best candidate" for a name, which can be
another checkout's device. Interactive use between commands isn't locked; another agent in the same
checkout may run tests on that device meanwhile.

### Xcode MCP

`.mcp.json` registers Xcode's MCP server (`xcrun mcpbridge`). It drives the running Xcode, with that
window's run destination and Xcode's own DerivedData, outside the lock. Call `XcodeOpenWorkspace`
with this checkout's `.xcodeproj` absolute path first, and pass the identifier it returns as every
call's `workspaceIdentifier`; the server rejects a path there, and the identifier lasts only for
that MCP session. Use it for build diagnostics, previews, snippets, and docs; run tests with `make
test-unit` / `make test-ui`, not `RunAllTests` / `RunSomeTests`. Before `RunProject` or a
device-interaction session, point it at this checkout's device: `XcodeSwitchRunDestination` to the
`iPhone 17 [<hash>]` entry, or `deviceIdentifier` set to the UDID. After
`DeviceInteractionInstallAndRun`, pass `activationBundleId: com.jimmyho.checklists` to the first
`DeviceInteractionSynthesize`, or it can land on a blank SpringBoard.

### The software keyboard

UI tests never tap keyboard keys; `make gate` fails on a new tap
(`scripts/check_ui_test_keyboard.py`); use the `XCUIElement+Keyboard.swift` helpers. **A UI failure
with `kAXErrorCannotComplete` on a keyboard key means a tap got past that check: say so explicitly in
your report** — never treat it as known flake.

## Simulator slots

Every simulator running tests takes a slot from a machine-wide pool that other opted-in repos
share. The pool's state, including its size (the `max` file), is in
`~/.local/state/simulator-slots/`. `scripts/simulator-slots/` is this repo's copy of the master in
`~/dev/simulator-slots`.

**The pool is on only where `~/dev/simulator-slots` exists** (Jimmy's machine). On any other
clone it is off: don't look for or create that directory or the state directory. Test scripts
take no slots and pass no parallel-testing flags, so they run serially on the checkout's own
device, the scheme's setting. The gate's sync check is skipped, and the rest of this section
doesn't apply.

- **Changing the tool:** never edit the copy. Change the master, then run `make
  simulator-slots-sync`. The gate fails while the two differ.
- **Slots per command:**
  - `test-unit` and `test-only`: 1.
  - `test-ui`: up to `UI_WORKERS`.
  - The size check's `run.sh`: up to `WORKERS`.
  - The screenshot lane: 1, held for the whole capture, its builds included: fastlane's snapshot
    builds and tests in one step.
- **How a run uses them:** it builds first, then takes whatever is free, at least 1. With 2 or
  more, it runs that many parallel clones of this checkout's device; the clones boot fresh, without
  the warm-up a one-slot run gets.
- **Fewer simulators for a task:** when Jimmy asks for fewer simulators for a task, prefix the
  command with `SIMULATOR_SLOTS_FEWER=N`. The run then leaves N of the free slots unused; N must be
  smaller than the pool.
  `SIMULATOR_SLOTS_TIMEOUT=S` makes it give up with exit 75 after waiting S seconds.
- **Waiting:** a run waiting for a slot prints who holds each one, so start suites with
  `run_in_background`. `make simulator-slots-status` shows the holders, every booted simulator, and
  the recent runs.
- **Idle devices still cost memory:** a booted simulator takes no slot but still uses about 2–3 GB.
  `/merge-pr` shuts down the merged checkout's devices.

## Known issues

- **The old Flurry API key is in git history** and gitleaks can't see it (a bare 20-char
  alphanumeric matches no rule), so a green secrets gate doesn't cover it.

## CI

`.github/workflows/ci.yml` is present but disabled (`workflow_dispatch` only; private repo, macOS
minutes bill at 10×). Enable instructions are in the workflow header.
