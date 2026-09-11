---
name: appstore-generate-screenshot-seeding
description: Prepare or validate reChecklist's deterministic App Store screenshot seed catalogs. Use for screenshot demo-content changes; refreshing screenshots alone reuses the existing catalogs.
---

# Prepare screenshot content

The active locale set is in `fastlane/screenshot-config.json`; currently only
en-US is enabled. Future localized catalogs use runtime-language filenames, with
explicit regional locale settings. Translation generation is deferred in GitHub
issue #161.

1. Read `fastlane/SETUP.md`, the screenshot configuration, and the existing
   `checklists/checklistsUITests/ScreenshotSeeds/` catalogs.
2. Reuse approved content unless the user asks to change seed content. A request
   to refresh or regenerate **screenshots** means recapture using the existing
   catalog; route it to `appstore-generate-push-screenshots`.
3. For an authorized content change, edit the catalog and relevant fixture tests.
   Preserve the English source's three lists, names, item order and notes. The
   screenshot-only override checks the first three Pre-Trip items. Morning Routine
   and Weekend Getaway retain their shipped checked states. Do not alter normal
   first-launch data to stage marketing screenshots.
4. Run `python3 scripts/screenshot_content/check_content.py`. Missing or invalid
   enabled locales must fail. Do not silently fill a translated catalog with
   English. Run the focused Swift seed tests when fixture data or decoding changes.
5. Report the verified catalog and active locales. Persist authored changes using
   `create-pr`. Capture is a separate step; this skill never uploads anything.

The catalog is bundled in the UI-test target and passed to the Debug-only
screenshot launch path. It must never seed the user's persistent store or sync
marketing content to CloudKit. The existing normal sample fixture remains the
source of truth for first-launch behavior.

After translation tooling is added, add localized catalogs and enable their
locales deliberately. Currency-specific fixture generation is outside this app's
requirements; do not make missing translation tooling a prerequisite for English
captures.
