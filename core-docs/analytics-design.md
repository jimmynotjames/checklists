# Analytics

**Status: stubbed. This app currently sends no analytics anywhere.**

Flurry Analytics 11.2.0 instrumented this app from 2019 until it was removed. Flurry reached end
of life; **Mixpanel is the intended replacement** but is not implemented. Every
`AnalyticsManager.log*` call site is still in place and still fires — into a no-op that prints in
DEBUG and does nothing in Release.

This document is the tracking plan for whoever implements Mixpanel — tracked in
[issue #118](https://github.com/jimmynotjames/checklists/issues/118). Everything the Flurry
integration did is recorded here, so the cutover is a matter of filling in bodies rather than
rediscovering intent.

The sibling **`budgets1`** repo has a complete, working Mixpanel implementation — see
`simple-recurring-budgets/Logging/` and `docs/analytics-spec.md` there. The naming conventions
below were deliberately aligned to it. Use it as the reference implementation.

## Where the code is

Everything lives in one file: `checklists/checklists/Analytics/AnalyticsManager.swift`.

- `enum AnalyticsManager` — static facade. 17 call sites across the app, all unchanged since the
  Flurry era.
- `logEvent(_:withParameters:)` — the single sink. **Swapping this one function body for
  `Mixpanel.mainInstance().track(event:properties:)` is the bulk of the cutover.** Its properties
  are typed `[String: Any]` (not Flurry's `[AnyHashable: Any]`) so the keys already match
  Mixpanel's `[String: MixpanelType]` and only the values need bridging — see the worked example
  in the function's doc comment, including the way `compactMapValues` silently drops values of the
  wrong type.
- `appLaunched()` — where SDK init and identify belong. Already calls `registerSuperProperties()`
  and logs `app_opened`.
- `registerSuperProperties()` — stub, documents the intended set. **Already called** from
  `appLaunched()`, before the first event, so filling in the body is sufficient.
- `enum AnalyticsEvent` / `enum AnalyticsProperty` — canonical name constants. No call site uses a
  string literal.

There is deliberately **no protocol, no dependency injection, and no client abstraction**. This is
a small UIKit/storyboards app with no SwiftUI environment to inject through; the static facade
already isolates the backend to two function bodies. `budgets1`'s `AnalyticsClient` protocol is the
right shape for a testable SwiftUI app, and would be over-engineering here.

## What Flurry did that Mixpanel will not

These are real gaps, not porting details:

| Flurry capability | Status under Mixpanel |
|---|---|
| **Crash reporting** (`withCrashReporting(true)`) | **Gone, deliberately not replaced.** Mixpanel does not do crash reporting, and the decision was made to rely on **Xcode Organizer alone** rather than take on a third-party crash SDK (Sentry, Crashlytics) with its dependency, token, and privacy-manifest surface. See "Diagnostics" below for what *is* captured. |
| **Automatic session tracking** (`startSession`) | **Not automatic.** Mixpanel derives sessions server-side from the event stream, so an explicit `app_opened` event must be sent on every foreground. `AnalyticsEvent.appOpened` exists for this. |
| Log-level control (`withLogLevel`) | Mixpanel has its own logging switch; not a concern. |
| GDPR/CCPA consent objects (`FlurryConsent`, `FlurryCCPA`) | Were vendored but **never used by this app**. Consent is an open decision — see below. |

## Diagnostics are a separate channel

`checklists/checklists/Logging/AppLoggers.swift` is the **diagnostics** channel: operational
failures a developer needs to see on a real device. It is architecturally independent of
`AnalyticsManager`, which is the **product** channel. The two never feed each other — the same
split `budgets1` documents in its `docs/analytics-spec.md` §17.

This exists because analytics are stubbed. Without it, a Realm failure would crash the app having
left no record anywhere in Release. `os_log` needs no backend, no SDK, and no network; it writes
to the unified log, readable in Console.app on an attached device and captured in a sysdiagnose.
It is also durable in a way an analytics call is not — the message reaches the logging daemon
synchronously, so it survives the `fatalError` that follows it in `DBManager`.

Verified by corrupting the Realm file on a simulator and relaunching:

```
F  checklists[...] [com.jimmyho.checklists:persistence] Realm could not be opened: Error
Domain=io.realm Code=20 ... header has invalid mnemonic
```

The error description is logged `%{public}@` on purpose. A Realm error is a file path and an error
code, not user content, and it is useless in a sysdiagnose if redacted to `<private>`. On device
the path is a container UUID, not anything identifying.

**When Mixpanel lands, keep these channels separate.** Do not route `os_log` output into Mixpanel,
and do not drop the `os_log` calls just because analytics start working again — they answer
different questions and have different durability.

### `app_opened` is currently under-fired

`appLaunched()` is called only from `ChecklistsApp.init()`, so
it fires on cold launch only. Under Flurry that was fine — the SDK handled foregrounding itself.
For Mixpanel it is wrong: a return from background is a session too. Wire it to
`applicationWillEnterForeground` / `sceneWillEnterForeground` as part of the Mixpanel change.
(`budgets1` solves this with an `AppOpenTracker` that filters out `.inactive` flicker — the
notification shade and app switcher are not opens.)

## Event catalog

All names are flat `snake_case`, `noun_pastTenseVerb`. The Flurry names are given because they are
what appears in any historical Flurry export — they are **not** what the code sends now. Renaming
was free: the Flurry data is not migrating to Mixpanel, so there was no continuity to preserve.

| Event | Flurry name | Fires when | Properties |
|---|---|---|---|
| `app_opened` | *(none — Flurry auto-tracked sessions)* | App launch. **Should also fire on foreground.** | *(none yet — super properties carry the context)* |
| `checklists_viewed` | `checklists_viewed` | Checklists list appears | `checklists_count` |
| `checklist_viewed` | `checklist_viewed` | A checklist is opened | `checklist_name`, `notes_length`, `items_count`, `items_with_notes_count` |
| `settings_viewed` | `settings_viewed` | Settings appears | — |
| `main_menu_viewed` | `main_menu_viewed` | Main menu appears | — |
| `checklist_created` | `create_new_checklist` | User creates a checklist | — |
| `checklist_reset` | `reset_checklist` | User unchecks all items in a checklist | — |
| `rate_app_tapped` | `rate_in_app_store` | "Rate in App Store" tapped | — |
| `feedback_tapped` | `send_feedback` | "Send feedback" tapped | — |
| `privacy_policy_tapped` | `view_privacy_policy` | Privacy policy opened | — |
| `persistence_fatal_error` | `realm/fatal_error` | The persistent store cannot be opened at all | `error` |
| `persistence_write_failed` | `realm/write_error` | A SwiftData save throws | `error` |
| `startup_failed` | *(none — the Realm build crashed instead)* | Launch could not produce a usable store, so the retry screen was shown: container creation, the one-time Realm import, or first-launch seeding failed | `error` |
| `startup_store_reset` | *(none)* | User chose "Start over fresh" on that screen, deleting this device's stores | — |
| `orientation_changed` | `orientation_changed` | Device rotates portrait↔landscape | `orientation` |

Slashes were dropped from the Realm event names — Mixpanel accepts them, but the flat convention
matches `budgets1` and reads better in the Mixpanel UI. The `realm/*` events became
`persistence_*` so they survive a future persistence-layer swap.

**`startup_failed` is the one to watch after the SwiftData migration.** It is the only signal that a
user was shown the failure screen instead of their checklists, so its count is the measure of how
often the store cannot be opened in the field. Note that no data has been lost when it fires — the
store simply would not open, and on the one launch that migrates the old Realm file is still
untouched on disk, with the import retried on the next launch (see
[`persistence-design.md`](persistence-design.md)).

**Note the error events are diagnostics, not product signals.** `persistence_fatal_error` fires
immediately before a `fatalError`, so in practice Mixpanel may never flush it — treat any count it
reports as a floor, not a total.

## Property catalog

| Property | Flurry key | Type | Notes |
|---|---|---|---|
| `checklists_count` | `num_checklists` | Int | |
| `checklist_name` | `name` | String | **Raw user content — see accepted risk below** |
| `notes_length` | `notesLength` | Int | The only camelCase key in the old catalog |
| `items_count` | `num_items` | Int | |
| `items_with_notes_count` | `num_items_with_notes` | Int | |
| `error` | `error` | String | Truncated to 127 chars by `truncatedString` |
| `orientation` | `orientation` | String | `portrait` / `landscape` |

Counts are sent raw rather than bucketed. Mixpanel handles numeric properties natively, and
`budgets1`'s bucketing is privacy-motivated — which would be inconsistent here, given we send the
checklist name.

### Removed: `ui_idiom`

`orientation_changed` used to carry `ui_idiom` (`iphone`/`ipad`/`carplay`/`tv`/…). It is constant
for an install, so it belongs on the profile, not on every rotation event. It becomes the
`device_class` super property (`phone`/`pad`, matching `budgets1`'s values).

Note the app is `TARGETED_DEVICE_FAMILY = 1` (iPhone only), so this is near-constant in practice —
it distinguishes iPad-running-an-iPhone-app from a real iPhone.

### Accepted risk: `checklist_name` is raw user content

`checklist_viewed` sends the checklist's name verbatim. This is a deliberate, eyes-open decision,
mirroring the way `budgets1` allow-lists `budget_name` — the product question ("what do people
actually make checklists for?") is not answerable any other way.

Constraints on it:

- It is the **only** free-text property this app sends. Item names, item notes, and checklist notes
  are never transmitted — only `notes_length` as a count.
- Adding any other user-content property is a new decision, not covered by this precedent.
- Revisit it alongside the consent work below. If a consent gate lands, this is the property that
  most needs to sit behind it.

## Super properties

Registered once per session and attached to every event. Stubbed in
`AnalyticsManager.registerSuperProperties()`; target is `Mixpanel.registerSuperProperties(_:)`.

| Property | Source | Under Flurry |
|---|---|---|
| `app_version` | `CFBundleShortVersionString` | Sent via `withAppVersion`, combined with build into one string |
| `app_build` | `CFBundleVersion` | Same — not separable |
| `device_class` | `UIDevice.current.userInterfaceIdiom` → `phone`/`pad` | Was the per-event `ui_idiom` |
| `locale` | `Locale.current.identifier` | Not collected |
| `region` | `Locale.current.region?.identifier` | Not collected |

`SettingsManager.versionBuildString` combines version and build into a display string (and appends
`- DEBUG` in debug builds). Do **not** send that — send `app_version` and `app_build` separately so
they can be filtered on.

## Published privacy disclosures are now out of date

**Action needed outside this repo.** The app's public disclosures were written while Flurry was
collecting, and the app now collects nothing:

- The **privacy policy** linked from `docs/index.md` is externally hosted (termsfeed). If it names
  Flurry or third-party analytics collection, it is now inaccurate.
- The **App Store Connect privacy nutrition label** was filled in for Flurry-era collection and
  likely still declares data types the app no longer gathers.

Neither lives in this repo, so neither could be fixed by the change that removed Flurry. Both will
need revising **twice**: once now to reflect "collects nothing", and again when Mixpanel ships. If
that is more churn than it is worth, the alternative is to leave them as-is only if they are
already generic enough to remain true — that is a judgement call requiring someone to actually read
the current policy text.

## Open decisions, deliberately deferred

None of these are built. Each is a real decision, not an oversight:

1. **Project token handling.** The Flurry API key was hardcoded in source for six years and is
   still in git history — [#115](https://github.com/jimmynotjames/checklists/issues/115). Do not
   repeat it. `budgets1` externalizes tokens to a gitignored `config/Secrets.local.xcconfig`,
   `#include?`'d by a committed `Secrets.xcconfig` holding placeholder sentinels, injected into
   Info.plist via `$(MIXPANEL_TOKEN)` and read from `Bundle.main`. It also has a
   `verify_release_secrets.sh` guard so a placeholder can never ship. Copy that whole mechanism.
   Note gitleaks did **not** catch the Flurry key (a bare 20-char alphanumeric with no adjacent
   keyword), so a green secrets gate proves nothing here.
2. **Separate dev and prod projects.** `budgets1` runs two Mixpanel projects and picks the token by
   `#if DEBUG`. The Flurry integration instead compiled *all* analytics out of debug builds, which
   made local instrumentation impossible to verify — the reason the stub prints to the console
   instead. Two projects is the better pattern.
3. **Consent / opt-in.** This app has never asked. `budgets1` has a locale-aware consent model
   (strict opt-in where required, auto opt-in elsewhere), a first-run consent sheet, an
   `analytics_consent_changed` event, and lazy SDK init so an opted-out install never opens a
   network connection. Decide this **before** shipping Mixpanel, not after — it interacts directly
   with `checklist_name` above.
4. **Persisted `distinct_id`.** Mixpanel generates a device-scoped id by default. `budgets1`
   generates a UUID once and persists it in `NSUbiquitousKeyValueStore` so one person unifies
   across devices without using any Apple identifier.
5. **`PrivacyInfo.xcprivacy`.** This app has no privacy manifest. Shipping a third-party analytics
   SDK is the point at which one is needed. `budgets1`'s declares `NSPrivacyTracking = false`, no
   tracking domains, and one collected data type (Product Interaction, linked, purpose Analytics).
6. **People properties.** Not used under Flurry at all. See `budgets1`'s §10.3 for the shape.
7. **App Tracking Transparency.** Out of scope, and should stay that way: initialize with
   `trackAutomaticEvents: false`, collect no IDFA, and no ATT prompt is required.

## Keeping this current

When the analytics surface changes — a new event, a property added to or removed from an existing
event, a new value in a categorical property, or a new super property — **update this file in the
same change**. The catalog above is the only record of what the app is supposed to emit; the
`AnalyticsEvent`/`AnalyticsProperty` enums are the only record of what it currently does.
