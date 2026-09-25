# Localized large-type layout check

An ad-hoc visual check: does the UI still hold together when a long translation
meets the largest Dynamic Type size? It is not part of `make gate` or any hook,
and it asserts nothing. The reading is the check.

```bash
bash scripts/translation-accessibility-size-check/run.sh --yes
```

Roughly 20-30 minutes serially. Screenshots land in `tmp/loc-size-check/`, named
`<lang>__<screen>.png`.

## What it does

Drives `LocalizationScreenshotCapture` (in `checklistsUITests`) through seven
screens in thirteen locales with Dynamic Type forced to `.xxxLarge`, then exports
and downscales the attachments.

The thirteen are chosen for what they stress, not for market size:

| Why | Locales |
| --- | --- |
| Right-to-left | `ar`, `he`, `ur` |
| Tall or stacked glyphs | `th`, `vi`, `hi`, `ta`, `bn` |
| Longest words | `de`, `fi` |
| CJK rendering | `ja`, `zh-Hans` |
| Cyrillic | `ru` |

Screens: the list, the main menu, settings, a checklist's detail, the list in
Edit mode, the delete confirmation, and a new checklist. The analytics consent sheet
is captured as `04a-consent` wherever the region presents it.

## Reading the results

Look for text that is clipped, truncated with an ellipsis where it matters, or
overlapping another control; for a control that has grown past the screen edge;
and in `ar`, `he`, and `ur`, for anything that failed to mirror — an icon,
a chevron, or a leading-edge inset that stayed on the left.

Record what you find in `AUDIT_LOG.md`, including the date and the fact that you
found nothing, if that is the outcome. An empty log is indistinguishable from a
check nobody ran.

## Known limitation

The checklist detail screen is UIKit and uses fixed fonts, so it does not scale
with Dynamic Type. Its screenshots are still worth reading for translation
length and right-to-left mirroring, but not for type size. See
`core-docs/accessibility-spec.md` §Dynamic Type and issue
[#183](https://github.com/jimmynotjames/checklists/issues/183).

## Dependencies worth knowing about

`run.sh` needs `jq` and `sips` and checks for both. The capture navigates by
accessibility identifier rather than visible text, so renaming `toolbar.mainMenu`,
`toolbar.edit`, `editBar.delete`, `toolbar.addChecklist`, `mainMenu.settings`, or
`analyticsConsentSheet.decline` breaks it silently. The type size is forced
through `TestDynamicTypeOverride`, which is DEBUG-only and inert unless launched
with both `IS_TESTING` and `FORCE_DYNAMIC_TYPE`.
