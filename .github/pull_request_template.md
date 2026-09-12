## What
*

## Why


## Test plan
- [ ]

## Tools
-

---

## Cross-cutting concerns

For every change, confirm each concern applies or is N/A:

- [ ] **SwiftData schema migration** — if `Checklist.swift`, `Item.swift`, or `SchemaV1.swift`
      changed, a new `VersionedSchema`, a `MigrationStage` in `ChecklistsMigrationPlan`, and a
      migration test all exist. Once the CloudKit production schema is deployed, changes are
      additive only. See `core-docs/persistence-design.md`.
- [ ] **Analytics** *(SDK not connected yet — events reach the console client, which prints in
      DEBUG and is silent in Release)* — new user-initiated state changes still fire a matching
      `analytics.track(...)` call, with names in the `AnalyticsEvent`/`AnalyticsProperty` enums in
      `Analytics/AnalyticsNames.swift` and a row added to `core-docs/analytics-spec.md`. No PII.
- [ ] **Accessibility** — new controls have `accessibilityLabel` and appropriate traits; nothing
      clips at large Dynamic Type.
- [ ] **Secrets inventory** — added, removed, or renamed secret-bearing files, credential variables,
      external secret locations, and machine-local credential prerequisites are reflected in
      `core-docs/secrets-list.md`; no secret values are documented or exposed during verification.

---

### 🧪 Running tests

Tests are **opt-in and not part of the gate** — `make gate` is format → lint → build only.
Both suites do run and pass, so run whichever the change warrants and state explicitly in the
Test plan above how it was verified — including "not run, verified manually in the simulator"
when that's the honest answer.

- `make test-unit` — runs entirely against in-memory `ModelContainer`s; it does not touch the
  simulator's real store.
- `make test-ui` — requires a prior `make test-unit` for the warm-up sentinel. If tests fail on
  `kAXErrorCannotComplete` against keyboard keys, that's the simulator's software keyboard being
  off, not your change — see AGENTS.md §"Known issues".

CI (`.github/workflows/ci.yml`) is present but **disabled** — no checks run on this PR.
