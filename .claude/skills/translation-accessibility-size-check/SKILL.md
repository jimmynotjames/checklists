---
name: translation-accessibility-size-check
description: "Capture and read localized screenshots at the largest Dynamic Type size to find truncation, overlap, and RTL mirroring faults. Visual review; asserts nothing."
---

# Localized large-type layout check

Does the UI hold together when a long translation meets the largest Dynamic Type size? Ad-hoc,
slow, and outside the app test suites and `make gate`.

## Run it

Read `scripts/translation-accessibility-size-check/README.md` first for the locale set; the knobs
(`WORKERS`, `SIMULATOR_NAME`, `MAX_PX`) are in the `run.sh` header.

```bash
bash scripts/translation-accessibility-size-check/run.sh --yes
```

Without `--yes` it prints its resource warning and exits 2. `WORKERS=6` parallelizes if the machine
has the RAM. Screenshots land in `tmp/loc-size-check/` as `<lang>__<screen>.png`.

## Read the results — this is the actual check

The run cannot fail on a layout fault. Open every screenshot and look for:

- text clipped, or truncated where the truncation loses meaning;
- a control grown past the screen edge, or two controls overlapping;
- in `ar`, `he`, and `ur`, anything that did not mirror: an icon, a chevron, a leading-edge inset
  still on the left;
- a translation so long the screen stops being usable: send it back through
  `translate-new-strings`; it isn't a layout bug.

The checklist detail screen uses fixed fonts, so ignore its type size; still check it for length
and mirroring.

## Record the outcome

Add an entry to `scripts/translation-accessibility-size-check/AUDIT_LOG.md`: date, what was
captured, what was found, what was done. **Record a clean run too.**

A layout fix belongs in the view; a wording fix belongs in the catalog, through the pipeline, never
by hand.
