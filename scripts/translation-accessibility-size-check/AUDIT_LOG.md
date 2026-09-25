# Localized large-type audit log

One entry per run of `scripts/translation-accessibility-size-check/run.sh`.
Record a clean run too: an empty log cannot be told apart from a check nobody
ran.

Format: date, what was captured, what was found, what was done about it.

The detail screen's fixed fonts are a known limitation
(`scripts/translation-accessibility-size-check/README.md` §Known limitation), not a
new finding.

## Runs

### 2026-09-19 — baseline

91 screenshots: 13 locales × 7 screens, `.xxxLarge`, iPhone 17 Pro Max, serial.
All 13 test methods passed.

**No layout faults found.** Nothing truncated, nothing clipped, no control past
a screen edge, no overlap. The longest translations behave: German's
"Packliste fürs Wochenende" and "Checkliste vor der Reise" fit one line at
`.xxxLarge`, and Finnish settings — "Jaa anonyymit käyttötiedot" beside its
switch, and a six-line privacy footer — fits without crowding the toggle.

**Right-to-left mirrors correctly** in `ar`, `he`, and `ur`, on both the SwiftUI
list and the UIKit detail screen: toolbar buttons swap sides, checkboxes and
progress rings move to the right edge, the back chevron flips, and the delete
confirmation puts the destructive action on the left.

**Two bugs found, both in the check itself, neither in the app.** Worth
recording because they are the kind that make a first run look like an app
failure:

1. The delete-confirmation step located the swipe-action button positionally,
   which failed in all 13 locales. Fixed with a `checklistRow.delete`
   identifier.
2. After that, it still failed in exactly `ar`, `he`, and `ur`: the swipe is
   mirrored under right-to-left, so `.trailing` actions sit on the left edge and
   a hardcoded left swipe reveals nothing. The capture now picks its direction
   per locale.

**Observations, not defects:**

- The UIKit detail screen does not scale, as expected. The contrast is visible
  within a single screenshot: its SwiftUI toolbar button scales while the item
  rows below it do not.
- Nastaliq (`ur`) sits tight vertically on the UIKit detail screen's metadata
  lines. It is legible and not clipped, but it is the least comfortable text in
  the set and is worth a second look if that screen is ever restyled.
- The analytics consent sheet did not appear in any of the 13, so there are no
  `04a-consent` shots in this run. The capture handles it by presence, so a
  future run in a strict region will pick it up without a code change.

### 2026-09-25 — Checklists list Edit mode

Three runs, each 91 screenshots: 13 locales × 7 screens, `.xxxLarge`. Screen 05 is now the list in
Edit mode (one row selected) instead of the removed reset popover.

**First run: two faults, both from long words at `.xxxLarge`.**

1. The nav bar's "Reset All" and "Edit" text buttons did not fit in `de` and `ta`. iOS moved the
   overflow into a "•••" menu, hiding Edit in `de` and both in `ta`, so the capture could not
   reach Edit mode there.
2. The Edit mode toolbar (Delete · Duplicate · Reset) was wider than the screen in `de` and `ru`,
   clipping Delete and Reset at the edges. `ja` spaced the three unevenly.

**Fix:** from `.xxLarge` up, Reset All and the three toolbar buttons show icons in every language,
keeping their words as the VoiceOver label and in the Large Content Viewer. Edit and Done never
collapse. The toolbar's items are now separated by `ToolbarSpacer`s.

**Final run: no layout faults.** All 13 test methods passed. Both bars fit in every locale; `ar`,
`he` and `ur` mirror the nav bar, the selection circles and handles, and the toolbar order.
Long checklist names truncate in Edit mode, where the handles take width; that is expected.

Not covered: `.xLarge`, the largest size that keeps the words, is not captured, so `de` and `ta`
there are unverified.
