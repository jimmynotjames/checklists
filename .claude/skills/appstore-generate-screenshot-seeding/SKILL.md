---
name: appstore-generate-screenshot-seeding
description: "Regenerate or validate the deterministic App Store screenshot seed catalogs from the string catalog. Use for demo-content changes; a screenshot refresh alone reuses them."
---

# Prepare screenshot content

The seeds under `checklists/checklistsUITests/ScreenshotSeeds/` are generated, never hand-edited:
`make gate` checks them against the catalog. What they are and why:
`core-docs/localization-spec.md §Screenshot seeds`.

## Changing demo content

1. Edit the English value in `checklists/checklists/DataModels/SampleData.swift` and the matching
   `sample.*` key in the catalog. They must agree; the generator joins on the English value.
2. Run `translate-new-strings` for the touched keys. `sample.*` keys go to the
   `sample-content-locale` agent, never the ordinary UI path.
3. Regenerate and check:
   ```bash
   python3 scripts/screenshot_content/generate_seeds.py
   python3 scripts/screenshot_content/check_content.py
   L=tmp/unit-tests-$$.log; make unit-tests > "$L" 2>&1; echo "$? $L"
   ```
4. Report the regenerated locales and open the PR with `create-pr`.

## Validating without changing anything

```bash
python3 scripts/screenshot_content/generate_seeds.py --check   # catalog vs seeds on disk
python3 scripts/screenshot_content/check_content.py            # shape, locale fields, parity with en-US
```

## Not this skill

- Refreshing or recapturing screenshots reuses the existing seeds: `appstore-generate-push-screenshots`.
- Never change first-launch data to stage screenshots, seed the user's persistent store, or sync
  marketing content to CloudKit. This skill never uploads.
