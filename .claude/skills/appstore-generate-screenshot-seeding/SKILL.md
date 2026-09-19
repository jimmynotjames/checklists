---
name: appstore-generate-screenshot-seeding
description: "Regenerate or validate the deterministic App Store screenshot seed catalogs from the string catalog. Use for demo-content changes; a screenshot refresh alone reuses them."
---

# Prepare screenshot content

The seed catalogs under `checklists/checklistsUITests/ScreenshotSeeds/` are
**generated, never hand-authored.** `en-US.json` supplies the structure and
`Localizable.xcstrings` supplies the words, from the same `sample.*` keys the app
uses on first launch, so a screenshot shows exactly what a new user sees.

Editing a seed file directly is a mistake: `make gate` regenerates and compares,
so the edit fails the gate instead of shipping. Change the source instead.

## Changing demo content

The sample strings live in the catalog, so a wording change is a translation
change, not a file edit.

1. Edit the English value in `checklists/checklists/DataModels/SampleData.swift`
   and the matching `sample.*` key in the catalog. The two must agree: the
   generator joins them on the English value and fails loudly if they drift.
2. Re-run the `translate-new-strings` skill for the touched keys. The `sample.*`
   namespace is **transcreated by Opus, not translated** — a locale's morning
   routine may open with a tea kettle where English opens with a coffee maker.
   Do not reuse the ordinary UI translation path for these keys.
3. Run `python3 scripts/screenshot_content/generate_seeds.py` to rewrite every
   locale's seed.
4. Run `python3 scripts/screenshot_content/check_content.py` and `make test-unit`.

Structure is deliberately fixed across locales: the same three lists, the same
ids and order, the same item counts, the same items reading as done. Only the
words change. `check_content.py` enforces that against the source locale, so a
reviewer comparing two locales is never guessing whether a difference is a
translation problem or a seeding one.

## Validating without changing anything

```bash
python3 scripts/screenshot_content/generate_seeds.py --check
python3 scripts/screenshot_content/check_content.py
```

The first reports drift between the catalog and the seeds on disk; the second
validates shape, locale fields, and parity with the source locale.

## Regenerating seeds is not regenerating screenshots

A request to refresh or recapture **screenshots** reuses the existing seeds and
belongs to `appstore-generate-push-screenshots`. Only a demo-content change
needs this skill. Do not alter normal first-launch data to stage marketing
screenshots, never seed the user's persistent store, and never sync marketing
content to CloudKit. `SampleData` remains the source of truth for first-launch
behavior; the seeds are its screenshot-time mirror.

Report the regenerated locales and persist changes with `create-pr`. Capture is a
separate step; this skill never uploads anything.
