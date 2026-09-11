---
name: appstore-generate-push-screenshots
description: Capture and review reChecklist App Store screenshots locally, inspect existing App Store screenshot sets, or explicitly publish reviewed screenshots to an existing editable version. Capture alone never authorizes uploading.
---

# Capture and publish screenshots

The workflow captures two screens for an explicit active locale set. Run commands
from the repository root. Read `fastlane/SETUP.md` and
`fastlane/screenshot-config.json` first.

## Capture and review

1. A refresh request reuses the committed seed catalog. Run
   `python3 scripts/screenshot_content/check_content.py`; route content changes
   to `appstore-generate-screenshot-seeding` only when requested.
2. Run `fastlane ios screenshots` and capture its full log under `tmp/`, retaining
   the real process exit status. The lane uses the repository's screenshot
   simulator, runs only `AppStoreScreenshots`, and does not authenticate with ASC.
3. Run `python3 scripts/screenshot_content/capture_progress.py status --run-id RUN_ID`
   and open `.build/screenshots/runs/RUN_ID/review.html`. Inspect both
   `01_checklists` and `02_pre_trip`: three distinct
   completion states, first three Pre-Trip items checked, no clipping or transient
   overlays, correct status bar and native Liquid Glass rendering.
4. Report the run ID, image paths, and verification result. Preserve that run for
   review. Capture-only work stops here even though this skill also supports upload.

Do not infer success from old images or a final filename. Require successful test
execution and validation of this run's complete expected image set. A failed
capture preserves its logs and partial output. Use the lane's subset/retry support
to retry only missing work, at most twice after diagnosis; stop on a repeated
build/test failure. Resume with `fastlane ios screenshots run_id:RUN_ID locales:en-US`
(enabled runtime locale codes). Omit `run_id` for a fresh capture; a resumed run
must still match its recorded source/configuration/seeds. Never clear good output
to retry a subset. Do not use direct `fastlane snapshot`; it bypasses isolation.

## Read-only App Store inspection

`fastlane ios inspect_screenshots` reports the primary language and existing
screenshot sets for the editable version, or the live version when none is
editable. It makes no changes. The primary language should be en-US for the
intended fallback. Existing explicit screenshots in other locales may take
precedence over fallback; report them before a future upload and do not delete
them without authorization.

## Publish only when explicitly requested

Resolve the explicit app version and reviewed capture run from the user's request
or release record. If either is ambiguous, ask before changing ASC. Use the
`push_screenshots` lane with `app_version:X.Y.Z` and the reviewed run ID; consult
`fastlane/SETUP.md` for exact options. It validates local artifacts first, then
requires the matching existing editable version and existing listing locales.

Publishing replaces screenshot sets only in the selected active locales. It does
not create a version/localization, change text metadata or availability, upload a
binary, or submit for review. English-only operation must not expand into the
metadata pipeline's 50-locale set.

The lane bounds deletion and upload retries and checks asset processing. Retain
the real exit status and log; a failure after deletion/upload may leave partial
remote state. Inspect the selected version and locale before retrying; do not
loop indefinitely or repeat already-confirmed locales. A subset retry retains
the same version and reviewed run. Report acceptance/processing accurately and
record the result in the active release record when applicable.

Never read or print the `.p8` key or `.env` contents. Fastlane may consume its
configured credentials internally for authorized inspection or publishing.
