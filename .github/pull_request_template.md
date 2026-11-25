## What
*

## Why


## End-user impact
<!-- Plain product language: what a user notices, how bad, how often. "None — internal only." is valid. -->


## Test plan
- [ ]

## Tools
-

---

## Cross-cutting concerns

For every change, confirm each concern applies or is N/A:

- [ ] **SwiftData schema migration** — if `Checklist.swift`, `Item.swift`, or `SchemaV1.swift`
      changed, a new `VersionedSchema`, a `MigrationStage` in `ChecklistsMigrationPlan`, and a
      migration test all exist. The CloudKit production schema is deployed, so changes are
      additive only. See `core-docs/persistence-design.md`.
- [ ] **Analytics events** — new user-initiated state changes fire a matching
      `analytics.track(...)` call, with names in the `AnalyticsEvent`/`AnalyticsProperty` enums in
      `Analytics/AnalyticsNames.swift` and a row added to `core-docs/analytics-spec.md`. No PII.
- [ ] **Accessibility** — new controls have `accessibilityLabel` and appropriate traits; nothing
      clips at large Dynamic Type. New or changed colors have their pair in `PaletteTests` (CI's
      `accessibility` shard checks contrast). If this change involved any accessibility work,
      `core-docs/accessibility-spec.md` is updated too.
- [ ] **Reduce Motion** — new or changed animations are gated on Reduce Motion
      (`@Environment(\.accessibilityReduceMotion)` / `UIAccessibility.isReduceMotionEnabled`), or
      carry a one-line rationale, with the verdict recorded in the animation inventory in
      `core-docs/accessibility-spec.md §Animation and Reduce Motion`.
- [ ] **Localization** — new user-facing strings are dotted keys with translator comments, read via
      `String(localized:defaultValue:comment:)`, and `translate-new-strings` has been run so
      `check_translations.py` passes. Sample-data changes also regenerate the screenshot seeds via
      the transcreation fan-out and `generate_seeds.py` — never hand-edit `Localizable.xcstrings` or
      a seed file. See `core-docs/localization-spec.md`.
- [ ] **Secrets inventory** — added, removed, or renamed secret-bearing files, credential variables,
      external secret locations, and machine-local credential prerequisites are reflected in
      `core-docs/secrets-list.md`; no secret values are documented or exposed during verification.

---

### 🧪 Running tests

The app's unit and UI suites are **opt-in and not part of the gate**; the tooling tests are
(AGENTS.md §"Build and test").
Both suites do run and pass, so run whichever the change warrants and state explicitly in the
Test plan above how it was verified — including "not run, verified manually in the simulator"
when that's the honest answer.

- `make unit-tests` — runs entirely against in-memory `ModelContainer`s; it does not touch the
  simulator's real store.
- `make ui-tests` — a run on one simulator warms it up with one unit suite first if needed. The tests don't tap
  keyboard keys, so a `kAXErrorCannotComplete` failure against one is a real regression — see
  AGENTS.md §"The software keyboard".

CI (`.github/workflows/ci.yml`) runs on this PR (AGENTS.md §CI).
