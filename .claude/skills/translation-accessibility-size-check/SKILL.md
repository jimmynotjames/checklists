---
name: translation-accessibility-size-check
description: "Capture and read localized screenshots at the largest Dynamic Type size to find truncation, overlap, and RTL mirroring faults. Visual review; asserts nothing."
---

# Localized large-type layout check

Answers one question: does the UI hold together when a long translation meets
the largest Dynamic Type size? It is ad-hoc, slow, and deliberately outside
`make test` and `make gate`.

## Run it

```bash
bash scripts/translation-accessibility-size-check/run.sh --yes
```

Without `--yes` it prints its resource warning and exits 2. Roughly 20-30
minutes serially; `WORKERS=6` parallelizes across simulator clones if the
machine has the RAM. Screenshots land in `tmp/loc-size-check/` as
`<lang>__<screen>.png`.

Read `scripts/translation-accessibility-size-check/README.md` first for the
locale set and what each one stresses.

## Read the results — this is the actual check

The run asserts nothing and cannot fail on a layout fault. Open every
screenshot. Look for:

- text clipped, or truncated where the truncation loses meaning;
- a control grown past the screen edge, or two controls overlapping;
- in `ar`, `he`, and `ur`, anything that did not mirror: an icon, a chevron, a
  leading-edge inset still on the left;
- a translation so long the screen stops being usable, which is a translation
  problem to send back through `translate-new-strings`, not a layout bug.

Ignore the checklist detail screen's type size: it is UIKit with fixed fonts and
does not scale. That is known, logged, and tracked in issue #183. Its
screenshots still matter for length and mirroring.

## Record the outcome

Write an entry in `scripts/translation-accessibility-size-check/AUDIT_LOG.md`
with the date, what was captured, what was found, and what was done. **Record a
clean run too** — an empty log is indistinguishable from a check nobody ran.

A layout fix belongs in the view; a wording fix belongs in the catalog. Do not
shorten a translation by editing `Localizable.xcstrings` by hand.
