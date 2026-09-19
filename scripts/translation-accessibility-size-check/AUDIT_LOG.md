# Localized large-type audit log

One entry per run of `scripts/translation-accessibility-size-check/run.sh`.
Record a clean run too: an empty log cannot be told apart from a check nobody
ran.

Format: date, what was captured, what was found, what was done about it.

## Standing caveat

The checklist detail screen is UIKit and uses fixed fonts, so it does not
respond to Dynamic Type at all. Do not log that as a new finding each time; it
is tracked in `core-docs/accessibility-spec.md` §2.3 and issue
[#183](https://github.com/jimmynotjames/checklists/issues/183). Its screenshots
are still worth reading for translation length and right-to-left mirroring.

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
confirmation puts the destructive action on the left. This is the first evidence
that right-to-left works at all in this app, since nothing had rendered in a
right-to-left locale before this PR.

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
