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

_No run recorded yet. The first one establishes the baseline: capture all 13
locales, read every screenshot, and write down what the app looks like at
`.xxxLarge` in each script before any of it is treated as a regression._
