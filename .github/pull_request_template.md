## What
*

## Why


## Test plan
- [ ]

## Tools
-

---

## Cross-cutting concerns

For any change that touches the data model, user actions, or UI — confirm each applies-or-N/A:

- [ ] **SwiftData schema migration** — if `Checklist.swift`, `Item.swift`, or `SchemaV1.swift`
      changed, a new `VersionedSchema`, a `MigrationStage` in `ChecklistsMigrationPlan`, and a
      migration test all exist. Once the CloudKit production schema is deployed, changes are
      additive only. See `core-docs/persistence-design.md`.
- [ ] **Analytics** *(no backend right now — Flurry removed, Mixpanel not wired up, so these
      calls are no-ops)* — new user-initiated state changes still fire a matching
      `AnalyticsManager.log*` event, with names in the `AnalyticsEvent`/`AnalyticsProperty` enums
      and a row added to `core-docs/analytics-spec.md`. No PII.
- [ ] **Accessibility** — new controls have `accessibilityLabel` and appropriate traits; nothing
      clips at large Dynamic Type.

---

### 🧪 Running tests

Tests are **opt-in and not part of the gate** — `make gate` is format → lint → build only.
Both suites do run and pass (68 unit tests, 17 UI tests), so run whichever the change
warrants and state explicitly in the Test plan above how it was verified — including "not run,
verified manually in the simulator" when that's the honest answer.

- `make test-unit` — runs entirely against in-memory `ModelContainer`s; it does not touch the
  simulator's real store.
- `make test-ui` — requires a prior `make test-unit` for the warm-up sentinel. If tests fail on
  `kAXErrorCannotComplete` against keyboard keys, that's the simulator's software keyboard being
  off, not your change — see AGENTS.md §"Known issues".

CI (`.github/workflows/ci.yml`) is present but **disabled** — no checks run on this PR.
