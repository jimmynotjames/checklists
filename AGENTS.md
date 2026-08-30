# Agent instructions — checklists

A UIKit + storyboards iOS app (Swift 5.0, iOS 13.2+), persisted with **Realm** (SPM). Analytics
are **stubbed** — Flurry was removed and Mixpanel is not wired up yet, so `AnalyticsManager.log*`
calls are no-ops. See
[`core-docs/analytics-design.md`](core-docs/analytics-design.md).

The Xcode project lives one level down at `checklists/checklists.xcodeproj`. The repo root holds
tooling, plus **`core-docs/`** — design docs that outlive any single change and are canonical for
their subject. (`docs/` is something else entirely: the published Jekyll/GitHub Pages site for the
privacy policy and landing page. Never put internal docs there.)

Tooling here was ported from the `budgets1` repo and deliberately trimmed — see
"Deviations from budgets1" at the bottom for what was changed and why.

## Build and test

```bash
make gate        # format-changed -> lint-changed -> build. The gate. Logs to tmp/gate.log.
make build       # compile only
make test-unit   # OPT-IN — not part of the gate
make test-ui     # OPT-IN — requires a prior `make test-unit` (simulator warm-up)
```

`make system` installs the toolchain (lefthook, swiftlint, swiftformat, gitleaks) and the
git hooks. Run it once per clone.

**Tests are not in the gate — and `make test-unit` currently FAILS TO LINK.** `RealmSwift`
and `Toast` are linked into the app target only, never into `checklistsTests`, so the test
bundle's direct Realm references have nothing to link against (`Undefined symbols for
architecture arm64`). This predates the tooling migration and is unrelated to the arm64 pin.
Tracked in [issue #116](https://github.com/jimmynotjames/checklists/issues/116); the fix is
adding both products to the test target's "Frameworks and Libraries" in Xcode. Whether the
2020-era assertions still pass is unknown — linking is only the first hurdle. `make test-ui`
has not been run and has the same missing-linkage shape.

**`make test-unit` wipes the simulator's app database.** `DataModelTests` tests against the
*persisted* Realm store (its own header says so) and calls `deleteAll()` in `setUp`. The
per-repo simulator sandbox keeps that blast radius on this repo's own device.

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

The test scripts no longer pass it at all: they build against a concrete simulator UDID, where
xcodebuild resolves a single arch anyway and the flag was a no-op.

**This project can be built for an x86_64 simulator again** — just drop the two `ARCHS` lines.

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

**Route branch → commit → PR → merge through the skills — don't hand-roll the pipeline.** The
skills are the canonical step-by-step spec (review, cross-cutting audit, gate, PR body, branch
cleanup, issue linkage); this section holds the conventions they cite:

- **Code already written, no issue:** `/create-pr`, then `/merge-pr <PR>`.
- **Issue → PR:** `/create-pr-for-issue <N>`, then `/merge-pr <PR>`.

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
- Don't hardcode an analytics token in source when wiring up Mixpanel. See
  [`core-docs/analytics-design.md`](core-docs/analytics-design.md) — the Flurry key sat in `AnalyticsManager.swift` for six years
  and gitleaks never caught it.

## Simulator sandbox

Each clone gets its own simulator, named `iPhone 17 [<8-char hash of the repo path>]`, so no
two clones — and no other repo — ever share a device. Managed automatically by
`scripts/_sim_sandbox.sh` (sourced via `scripts/_destination.sh` by the test scripts only;
`make build` uses a generic destination and never boots a simulator).

Overrides: `SIMULATOR_NAME` picks a different base device; `SIMULATOR_UDID` pins a specific
device and skips sandbox management entirely.

## Known issues

- **Analytics send nowhere.** Flurry was removed; Mixpanel is not implemented. Every
  `AnalyticsManager.log*` call still fires but hits a no-op (it prints in DEBUG). The full
  tracking plan, the event/property catalog, and the decisions still open are in
  [`core-docs/analytics-design.md`](core-docs/analytics-design.md) — read it before touching analytics.
- **The old Flurry API key is still in git history.** It left the working tree with the Flurry
  removal, but it is present in ~294 commits of history and **the gitleaks gate does NOT catch
  it** — the key is a bare 20-char alphanumeric with no adjacent keyword and gitleaks ships no
  Flurry-specific rule. Do not mistake a green secrets gate for this being handled. The Flurry
  account should be shut down; tracked in
  [issue #115](https://github.com/jimmynotjames/checklists/issues/115).
- **Test targets don't link their SPM dependencies** — `make test-unit` fails at link time.
  [issue #116](https://github.com/jimmynotjames/checklists/issues/116).

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
| gate = format → lint-fix → build → **test** | build only, tests opt-in | legacy suites not yet proven green |
| `build.sh` boots the per-repo simulator | generic destination, no boot | saves 30–90 s; only tests need a device |
| `SRB_SIM_MAX` sim-clone concurrency | not ported | UI suite is small and not gated |
| `--header strip` | `--header ignore` | would delete every file's authorship header |
| CI on by default (public repo, free macOS minutes) | ported but disabled | private repo, macOS bills at 10× |
| i18n gates, fastlane, OpenSpec | not ported | no counterpart stack here |
| Mixpanel analytics | not ported *yet* | Flurry removed; budgets1's `docs/analytics-spec.md` and `Logging/` are the reference for the eventual port. See [`core-docs/analytics-design.md`](core-docs/analytics-design.md) |
