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

- [ ] **Realm schema migration** — if `RealmSchema.swift` changed, a bumped `schemaVersion` and
      migration block exist. Without one the app `fatalError`s on launch for every existing user.
- [ ] **Analytics** *(no backend right now — Flurry removed, Mixpanel not wired up, so these
      calls are no-ops)* — new user-initiated state changes still fire a matching
      `AnalyticsManager.log*` event, with names in the `AnalyticsEvent`/`AnalyticsProperty` enums
      and a row added to `core-docs/analytics-design.md`. No PII.
- [ ] **Accessibility** — new controls have `accessibilityLabel` and appropriate traits; nothing
      clips at large Dynamic Type.

---

### 🧪 Running tests

Tests are **opt-in and not part of the gate** — `make gate` is format → lint → build only.
`make test-unit` currently **fails to link** (RealmSwift/Toast are not wired into the test
targets, [#116](https://github.com/jimmynotjames/checklists/issues/116)), so neither suite can run
until that is fixed. State explicitly in the Test plan above how the change was verified.

CI (`.github/workflows/ci.yml`) is present but **disabled** — no checks run on this PR.
