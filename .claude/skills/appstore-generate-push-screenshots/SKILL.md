---
name: appstore-generate-push-screenshots
description: "Capture and review App Store screenshots locally, inspect existing sets, or publish reviewed screenshots to an editable version. Capture never authorizes upload."
---

# Capture and publish screenshots

The workflow captures two screens per active locale on each configured device.
A full run is serial release-time work (timing: `fastlane/SETUP.md`) and is
resumable by `run_id`; use a `locales:` subset while iterating. Run commands
from the repository root. Read `fastlane/SETUP.md` and
`fastlane/screenshot-config.json` first.

## Capture and review

1. A refresh request reuses the committed seed catalog. Run
   `python3 scripts/screenshot_content/check_content.py`; route content changes
   to `appstore-generate-screenshot-seeding` only when requested.
2. Run `fastlane ios screenshots` and capture its full log under `tmp/`, retaining
   the real process exit status. The lane uses the repository's screenshot
   simulator for each device, runs only `AppStoreScreenshots`, and does not authenticate with ASC.
3. Run `python3 scripts/screenshot_content/capture_progress.py status --run-id RUN_ID`
   and open `.build/screenshots/runs/RUN_ID/review.html`.
   Inspect both `01_checklists` and `02_pre_trip` on each device: three distinct
   completion states, first three Pre-Trip items checked, no clipping or transient
   overlays, correct status bar and native Liquid Glass rendering.
4. Report the run ID, image paths, and verification result. Preserve that run for
   review. Capture-only work stops here even though this skill also supports upload.

Do not infer success from old images or a final filename. Require successful test execution and
validation of this run's complete expected image set. A failed capture preserves its logs and
partial output. Use the lane's subset/retry support to retry only missing work, at most twice
after diagnosis; stop on a repeated build/test failure. Resume with
`fastlane ios screenshots run_id:RUN_ID locales:ar,ja,de` (runtime locale codes); omit
`run_id` for a fresh capture, but a resumed run must still match its recorded
source/configuration/seeds. Never clear good output to retry a subset. Do not use direct
`fastlane snapshot`; it bypasses isolation.

## Read-only App Store inspection

`fastlane ios inspect_screenshots` reports the primary language and existing screenshot sets; it
makes no changes. Lane behaviour, fallback rules, and the no-op guarantees: `fastlane/SETUP.md`
§"Screenshot publication".

## Publish only when explicitly requested

Resolve the explicit app version and reviewed capture run from the user's request
or release record. If either is ambiguous, ask before changing ASC. Use the
`push_screenshots` lane with `app_version:X.Y.Z` and the reviewed run ID; consult
`fastlane/SETUP.md` for exact options. It validates local artifacts first, then
requires the matching existing editable version and existing listing locales.

A reviewed run covers every active locale. `locales:` takes
a subset of **runtime** codes, not storefront codes, for a spot check or a
retry. Before any `push_screenshots`, open the run's `review.html` and look
specifically at right-to-left layout in `ar`, `he`, and `ur`, at glyph rendering
in the CJK locales, and at the longest translations, which are usually German
and Finnish, for truncation.

The lane bounds deletion and upload retries and checks asset processing. Retain
the real exit status and log; a failure after deletion/upload may leave partial
remote state. Inspect the selected version and locale before retrying; do not
loop indefinitely or repeat already-confirmed locales. A subset retry retains
the same version and reviewed run. Report acceptance/processing accurately and
record the result in the active release record when applicable.

Never read or print the `.p8` key or `.env` contents. Fastlane may consume its
configured credentials internally for authorized inspection or publishing.
