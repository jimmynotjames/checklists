# Analytics Spec

This is the canonical description of what this app measures, what it refuses to measure, and how
the measurement is wired. Where this document and the code disagree, one of them is a bug — say
which in the PR. The sibling `simple-recurring-budgets` repo (the **Wren** app) has the reference
Mixpanel implementation; §16 records every place this app's conventions intentionally diverge.

Events reach the Dev project from Debug builds today. **No App Store build carries the SDK yet** —
see §15 for what that means for the published disclosures.

---

## 1. Status and scope

Flurry Analytics 11.2.0 instrumented this app from 2019 until it was removed at end of life. Every
`log*` call site survived that removal and has been firing into a no-op ever since. **Mixpanel is the
replacement.**

- Vendor: Mixpanel (`mixpanel-swift`, SPM, pinned `upToNextMajorVersion` from 6.5.0).
- Projects: `reChecklist App - Prod` (4062256) and `reChecklist App - Dev` (4062257), selected by
  `#if DEBUG`.
- Plan: Growth — unlimited saved reports, $0/month under the 1M-events/month allotment.
- Automatic events: **Off.** `trackAutomaticEvents: false`.
- Crash reporting: **None.** Mixpanel does not do it, and no third-party crash SDK is taken on.
  Xcode Organizer only.
- App Tracking Transparency: **Out of scope and staying there.** No IDFA, no ATT prompt.
- Sessions: derived server-side from the `app_opened` event stream. Mixpanel has no `startSession`.

Two Flurry capabilities are **gone, deliberately**: automatic session tracking (replaced by an
explicit `app_opened` on every foreground) and crash reporting.

## 2. Canonical constraints

These hold for all analytics work in this repo. A change that breaks one of them is a spec change,
not an implementation detail.

1. **No PII beyond the single allow-listed exception in §4.** The default is deny.
2. **Consent is locale-aware.** Strict opt-in where required (§6.2); auto opt-in elsewhere.
3. **An opted-out install never opens a Mixpanel connection.** SDK init is lazy, gated behind the
   opt-in check — not an SDK-level opt-out call after initialization.
4. **`OSLog` output is never forwarded to analytics** (§11), and analytics calls never replace an
   `OSLog` call.
5. **No string literals at call sites.** Every event and property name comes from the constants in
   `Analytics/AnalyticsNames.swift`, so a typo is a compile error.
6. **The project token is never a source literal.** It is injected via xcconfig → Info.plist (§10).
7. **No engagement-pressure events.** This app does not measure how to nag people. The two
   rating-prompt events (§8) are not an exception: they record when the app's own fixed bar was met
   and when it asked, so the bar can be sanity-checked — not how to move anyone toward it, and no
   outcome is observable at all (§3.9).
8. **Counts on events are raw; cohort signals on profiles are bucketed** (§9).

## 3. Product questions

This app is small and free, with no funnel and no revenue. The questions worth answering are
correspondingly few — this section exists so a dashboard can be justified by a question rather than
by what happens to be easy to chart.

| # | Question | Served by |
| --- | --- | --- |
| 3.1 | How many people use the app, how often, and are they coming back? | `app_opened`, retention |
| 3.2 | What do people actually make checklists *for*? | `checklist_name` (§4.4) |
| 3.3 | How big do checklists get — items, notes, how many lists per person? | `checklists_count`, `items_count`, `notes_length` |
| 3.4 | Is the notes feature used at all, or is it dead weight? | `items_with_notes_count`, `notes_length` |
| 3.5 | Do people reset checklists (reuse), duplicate them (template), or just make new ones (disposable)? | `checklist_reset` vs `checklist_duplicated` vs `checklist_created` vs `checklist_deleted` |
| 3.6 | How often does the store fail to open in the field, and how often is that unrecoverable? | `startup_failed` / `startup_store_reset`, filtered to `startup_stage = store_open` |
| 3.7 | Does anyone rotate the device? (The orientation-notification cost is only worth paying if so.) | `orientation_changed` |
| 3.8 | What share of installs opt out, and how does that differ by jurisdiction? | `analytics_consent_changed`, `consent_jurisdiction` |
| 3.9 | When do people reach the bar for the automatic App Store review prompt, and how soon after does the app actually ask? | `rating_prompt_eligible` → `rating_prompt_requested`, `time_since_first_eligible_bucket` |
| 3.10 | How often does an upgrading user's old data end up permanently out of reach? | `startup_failed` filtered to `startup_stage = legacy_import`, and `legacy_import_abandoned` |

Question 3.9 stops at the request, deliberately. The prompt is Apple's native `requestReview`,
which reports neither whether StoreKit showed the dialog nor what the person chose — there is no
callback — so shown / dismissed / rated is not a question this app can answer. No custom pre-prompt
is added to manufacture that signal: review-gating hurts ratings and would breach constraint 7.
The bar itself (seven days installed, three distinct days with a check-off, ten check-offs,
once per app version) is `simple-recurring-budgets`'s calibration ported as-is; if 3.9 shows it is
met too early or too rarely, the thresholds are three constants on `RatingPromptCoordinator`.

Question 3.7 has a defined end: `ChecklistsApp` carries a `TODO-DEFERRED` about the power cost of
`beginGeneratingDeviceOrientationNotifications()`. Once `orientation_changed` has an answer, that
call and the event should both be reconsidered.

## 4. Privacy contract — PII and field-level rules

### 4.1 General principle

**The default is deny.** A field is transmitted only if it appears in §4.2. Adding anything to that
list is a spec change requiring a rationale recorded here — not a code review comment.

### 4.2 Allow-list

| Field / category | Allowed | Rationale |
| --- | --- | --- |
| Screen-view and action events | Yes | The core product signal. No user content. |
| Counts (`checklists_count`, `items_count`, `items_with_notes_count`) | Yes | Integers. Answer §3.3/§3.4 with no content. |
| `notes_length` | Yes | A character count, never the characters. |
| `checklist_name` | **Yes — accepted risk, see §4.4** | The only free-text field. Nothing else answers §3.2. |
| `orientation` | Yes | `portrait` / `landscape`. |
| `source` | Yes | `menu` / `swipe`. Names an affordance the app owns, never anything the person typed. |
| `error_domain`, `error_code`, `error_operation`, `startup_stage` | Yes | A SwiftData/CloudKit error domain, its integer code, which save failed, and how far launch got. Structured — the last two are app-authored and enumerated — never an `NSError`'s `userInfo`, see §4.3. |
| App version, build, locale, region, device class | Yes | Standard environment context (§9.2). |
| A generated `distinct_id` UUID | Yes | Random, app-generated, not derived from any device or Apple identifier (§5). |

### 4.3 Deny-list

| Field / category | Denied | Rationale |
| --- | --- | --- |
| **Item names** | Never | The bulk of user content. `items_count` is sufficient. |
| **Item notes** | Never | Free text. `items_with_notes_count` is sufficient. |
| **Checklist notes** | Never | Free text. `notes_length` is sufficient. |
| Any Apple identifier (IDFA, IDFV, device name) | Never | No tracking, no ATT (§1). |
| IP-derived geolocation (`$city`, `$region`, `mp_country_code`) | Never | Mixpanel derives these from the request IP unless told not to; `MixpanelAnalyticsClient` sets `useIPAddressForGeoLocation = false`. The device's own settings are the location signal instead (§9.2) — a *setting*, not a *position* — which is why no location data type is declared in `PrivacyInfo.xcprivacy`. |
| iCloud account identifiers or CloudKit record names | Never | Identity is the app-generated UUID only. |
| An `NSError`'s `userInfo`, `description` or `localizedDescription` | Never | `userInfo` is unbounded and can serialise the user's own content. Send `error_domain` and `error_code` instead — the same rule `ContainerCreationFailure` and the `OSLog` `privacy:` annotations already follow. |
| Any `OSLog` message text | Never | Separate channel (§11). |
| Contents of the Realm import (legacy data) | Never | Only the import's success/failure reaches analytics, via `startup_failed`. |

### 4.4 Accepted-risk exception: `checklist_name`

`checklist_viewed` sends the checklist's name verbatim, truncated to 127 characters. This is a
deliberate, eyes-open decision mirroring the way `simple-recurring-budgets` allow-lists
`budget_name`. **Question §3.2 — what do people actually make checklists for? — is not answerable
any other way**, and it is the single most valuable product question this app has.

Constraints on the exception, all of which are load-bearing:

- It is the **only** free-text property this app transmits. Everything else in §4.3 stays denied.
- Adding any other user-content property is a **new decision**, not covered by this precedent.
- It sits **behind the consent gate**. This is why the first-run consent sheet is triggered by the
  first `checklist_viewed` rather than at launch or on first write (§6.2) — the gate is placed
  immediately before the riskiest event can first fire.
- It is declared in `PrivacyInfo.xcprivacy` as `NSPrivacyCollectedDataTypeOtherUserContent`, which is
  the reason this app's privacy manifest differs from Wren's (§16).
- Revocation trigger: if this property ever proves uninteresting in practice, or if the disclosure
  burden grows, drop it. It is the first thing to cut.

### 4.5 Enforcement

There is no automated PII check, and a lint rule could not tell a name from a count. Enforcement is:

1. This contract restated as a doc comment on the `AnalyticsClient` protocol, where anyone adding a
   `track` call will read it.
2. Constants-only names (§2.5), so the property vocabulary is enumerable in one file.
3. The **Analytics** item in `.github/pull_request_template.md`, and the cross-cutting audit in the
   `/create-pr` and `/create-pr-for-issue` skills, both of which point at this document.

## 5. Identity

A **UUIDv4 generated once by the app** and persisted, used as the Mixpanel `distinct_id`. It is not
derived from any Apple identifier, and it is not the IDFV.

**Stored in `UserDefaults.standard`, not `NSUbiquitousKeyValueStore`.** This is a deliberate
deviation from `simple-recurring-budgets`, forced by a real constraint: `checklists.entitlements`
declares CloudKit but **not** `com.apple.developer.ubiquity-kvstore-identifier`, so the iCloud
key-value store would not sync. Adding that entitlement means a capability change, a regenerated
provisioning profile, and an App Store Connect edit — a bad thing to bundle into the change that
also introduces a third-party SDK.

Accepted consequences:

- The consent decision and the `distinct_id` are **per-device, not per-person**. Someone using the
  app on an iPhone and an iPad counts as two. Given `TARGETED_DEVICE_FAMILY = 1`, this is rare.
- It is arguably the more privacy-conservative option, since nothing about the install leaves the
  device's own defaults.
- Migrating later is a one-line change to the store injected into `AnalyticsSettings`, plus a
  read-through migration, precisely because access goes through the `KeyValueStore` seam.
- `RatingPromptState` — the review prompt's install date and usage counters — sits behind the same
  seam and in the same `UserDefaults.standard`, for the same reason. Those counters are **not**
  analytics state and are not consent-gated: an opted-out install still earns its prompt on the
  same schedule, and only the two events about it are suppressed.

**`StoreReset.startOverFresh()` does not clear the analytics keys.** A data reset is not a consent
withdrawal, and silently re-prompting someone who already declined would be worse than keeping the
decision. This is asserted by a test because it is otherwise invisible.

## 6. Consent

### 6.1 The always-on Settings toggle

Every install, in every jurisdiction, can turn analytics off at any time from Settings. Nothing below
removes that.

### 6.2 Strict-opt-in jurisdictions and the first-run sheet

In the regions listed below, analytics default to **off** and stay off until the person explicitly
accepts. Everywhere else, analytics default to **on** with the §6.1 toggle available.

The strict-opt-in region set, with the legal basis per entry, is
`ConsentJurisdiction.strictOptInRegions` in `Analytics/ConsentJurisdiction.swift`. An unknown region
resolves to `.required` — the conservative default, and covered by a test.

**The resolved default is never written to the store.** Whether a choice has been made explicitly is
exactly `store.object(forKey:) != nil`, and that is what gates the sheet. Writing the default at
launch would make every install look like it had already decided.

**Trigger: the first `checklist_viewed` on an existing (pushed) checklist.**
`simple-recurring-budgets` triggers its sheet after the first `budget_created`; that does not port,
because **this app seeds sample checklists on first launch**, so a person may never create one and
could use the app indefinitely without being asked. Opening a checklist is this app's core loop,
always happens, and happens after the product has shown its value. Decisively, it is the moment
`checklist_name` (§4.4) would first be transmitted.

The trigger is guarded to the *pushed* presentation only: in the new-checklist route the checklist
screen **is** the presented sheet, and asking for consent there would replace the sheet the person is
looking at.

**No retroactive replay.** Events that occur before consent is granted are dropped, not buffered.
Accepting starts the stream from that moment.

### 6.3 Toggle-off behavior

The order is the contract, and it is the reason this logic lives in a testable controller rather than
inline in a SwiftUI binding:

1. Track `analytics_consent_changed` with `new_value: false` — **while still opted in**, so the event
   can actually be sent. This is the only record that an opt-out happened.
2. `analytics.reset()` — clears the Mixpanel instance and its queued events.
3. Set the stored flag to `false`.

Toggle-**on** mirrors it: set the flag first, so the lazy initializer sees an opted-in state, then
track, then set the opt-in timestamp people property.

Declining the first-run sheet — including by swiping it away — writes an **explicit** `false` and
sends nothing. Without the swipe-to-dismiss handling the sheet would re-present on every checklist
open.

## 7. Architecture: two independent paths

### 7.1 Client selection

- Running tests (`-UITests1` launch arg **or** `IS_TESTING` env var) → `ConsoleAnalyticsClient`.
- Tokens are still placeholder sentinels (fresh clone) → `ConsoleAnalyticsClient`.
- Otherwise → `MixpanelAnalyticsClient`.

All three are reachable: `ChecklistsApp.shouldUseConsoleClient(isRunningTests:isTokenConfigured:)`
is the truth table above, and `makeAnalyticsClient()` calls it before constructing either client.

The test guard delegates to the existing `LaunchModeContainerFactory.isRunningTests`, which already
handles **both** signals. `simple-recurring-budgets` checks only its `IS_TESTING` env var; ported
literally, that would let this repo's UI-test runs send real events, because the XCUITest bundle
passes only the launch argument.

`ConsoleAnalyticsClient` prints in DEBUG and does nothing in Release. It is also the environment
default, so a SwiftUI preview or a view constructed in isolation never needs a real client.

### 7.2 Launch and consent-transition ordering

**Cold launch.** Build the client → wrap it in the consent gate → install the wrapped client for
the pre-environment call sites (§7.3) → construct the startup model → inject the wrapped client
into the environment for every startup phase → fire `app_opened` once the scene becomes active.

**The opt-in gate is a decorator, not internal to any one client.**
`ConsentGatedAnalyticsClient` wraps whichever client §7.1 selects and suppresses every method
except `reset()` while the person is opted out; `reset()` always passes through, since a gated
reset could never clear state on the transition that needs it. `ChecklistsApp.init()` builds it
once, around the base client, before installing anything — every call site, SwiftUI and
non-SwiftUI alike, reaches the base client only through this one gate.

**SDK initialization is lazy, and the gate is what makes that hold without either client knowing
about consent.** `Mixpanel.initialize` is not called in `MixpanelAnalyticsClient`'s own
initializer; it happens inside `ensureInitialized()`, called from that client's `track`. A
`track` the gate suppresses never reaches the wrapped client at all, so an install that is opted
out never constructs a Mixpanel instance and never opens a socket — the same guarantee as before,
now enforced one layer up instead of inside the Mixpanel client itself.

**After `reset()`** the instance is discarded. A later opt-in re-runs the full lazy init, which
re-registers super properties and re-identifies — this is why super-property registration lives
inside the initializer rather than at a single launch call site.

### 7.3 Reaching the client from non-SwiftUI code

**This is the part most likely to be got wrong.** Three call sites run before any SwiftUI environment
exists, and two more are in UIKit.

**The UIKit checklist screen** (`ChecklistViewController`) receives the client as a stored property,
assigned by its SwiftUI host in `makeUIViewController`, alongside everything else that screen is
handed there — its model context, its checklist, and the callbacks it reports back through. The
client defaults to the console one, so a missed injection degrades to "no events" rather than a
crash. That is not true of every property assigned there: the model context has no safe default.

**The three persistence sites** — the container factory, the startup coordinator, and the save
helper — cannot reach an environment: they run inside `AppStartupModel.init()`, itself inside a
stored-property initializer of the app struct. Each takes an injectable parameter defaulting to a
narrow process-wide handle, modeled on the existing `PersistenceController.shared` / `install(_:)`
pattern. The default keeps the ~15 existing `saveChanges` callers untouched; the parameter makes all
three testable.

> ⚠️ **Ordering requirement.** `AppStartupModel.init()` synchronously runs the whole startup
> sequence, and as a stored-property initializer it executes **before the body of the app struct's
> `init()`**. The analytics handle must therefore be installed *before* the startup model is
> constructed — which means the startup model cannot use an inline property initializer. Get this
> wrong and the three persistence events silently go to the console client forever, in every build,
> with no error.

**Every name constant is `nonisolated`.** The project sets
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, but SwiftData `@Model` types are not MainActor, so a
`Checklist` extension — such as the one assembling `checklist_viewed`'s properties — is nonisolated
and cannot reach a MainActor-isolated constant. Declaring `AnalyticsEvent`, `AnalyticsProperty` and
`AnalyticsText` members `nonisolated` is what lets names be used from anywhere, which is the whole
point of having them in one place. `simple-recurring-budgets` does the same, for the same reason. A
new constant without `nonisolated` compiles until the first model extension tries to use it.

**Consent interacts with this and it is not a bug.** These three error events are consent-gated like
everything else, so in strict-opt-in jurisdictions they are dropped on exactly the launch where they
would matter most. That is correct under §6.2's no-retroactive-replay rule, and it is precisely why
the `OSLog` channel (§11) remains the complete record. Do not "fix" it by exempting them.

## 8. Event catalog

All names are flat `snake_case`, `noun_pastTenseVerb`.

| Event | Fires when | Properties | Answers |
| --- | --- | --- | --- |
| `app_opened` | Cold launch, **and** every return from background | — (super properties carry context) | §3.1 |
| `checklists_viewed` | The checklists list appears | `checklists_count` | §3.3 |
| `checklist_viewed` | A checklist is opened | `checklist_name`, `notes_length`, `items_count`, `items_with_notes_count` | §3.2, §3.3, §3.4 |
| `settings_viewed` | Settings appears | — | §3.1 |
| `main_menu_viewed` | The main menu appears | — | §3.1 |
| `checklist_created` | A checklist is created | — | §3.5 |
| `checklist_duplicated` | A checklist is copied, from the list's swipe action or the checklist screen's menu | `source` | §3.5 |
| `checklist_reset` | All items in a checklist are unchecked | — | §3.5 |
| `checklist_deleted` | A checklist is deleted, from the list's swipe action or the checklist screen's menu | — | §3.5 |
| `rate_app_tapped` | "Rate in App Store" tapped | — | §3.1 |
| `feedback_tapped` | "Send feedback" tapped (main menu **or** the failure screen) | — | §3.1 |
| `privacy_policy_tapped` | The privacy policy is opened | — | §3.1 |
| `orientation_changed` | Device rotates portrait ↔ landscape | `orientation` | §3.7 |
| `persistence_fatal_error` | The store cannot be opened at all | `error_domain`, `error_code` | §3.6 |
| `persistence_write_failed` | A SwiftData save throws | `error_domain`, `error_code`, `error_operation` | §3.6 |
| `startup_failed` | Launch could not produce a usable store, so the failure screen was shown | `error_domain`, `error_code`, `startup_stage` | §3.6 |
| `startup_store_reset` | "Start over fresh" chosen on that screen, deleting this device's stores. Only offered when `startup_stage` was `store_open` | — | §3.6 |
| `legacy_import_abandoned` | The Realm import failed `LegacyRealmImporter.maximumAttempts` times and was given up on. The file is kept, but this release stops trying | `error_domain`, `error_code` | §3.10 |
| `analytics_consent_changed` | The consent toggle or first-run sheet changes the setting | `new_value`, `old_value` | §3.8 |
| `rating_prompt_eligible` | The install first meets every review-prompt threshold. **Once per install**, gated by the persisted `firstEligibleAt` | — | §3.9 |
| `rating_prompt_requested` | The app calls Apple's native `requestReview`. De-duplicated per app version by the local once-per-version guard | `time_since_first_eligible_bucket` | §3.9 |

**The rating-prompt events fire from `RatingPromptCoordinator`, not the screen** — see its doc
comment for the check-off, eligibility, and presentation-gating mechanics.

## 9. Property catalog

### 9.1 Per-event properties

| Property | Type | Values / notes |
| --- | --- | --- |
| `checklists_count` | Int | Raw, not bucketed. |
| `checklist_name` | String | **Raw user content**, truncated to 127 chars. See §4.4. |
| `notes_length` | Int | Character count of the checklist's notes. 0 when absent. |
| `items_count` | Int | |
| `items_with_notes_count` | Int | Counts items whose notes are non-nil *and* non-empty. |
| `source` | String | `menu` / `swipe`. Which affordance started a duplication. `checklist_duplicated` only. |
| `error_domain` | String | An `NSError` `domain`, e.g. `NSCocoaErrorDomain`. Framework-authored. |
| `error_code` | Int | An `NSError` `code`. Sent as an Int, not a string. |
| `error_operation` | String | `PersistenceOperation.rawValue`: `checklistEdit`, `itemEdit`, `itemUpdate`, `reorder`, `delete`, `legacyImport`, `sampleSeed`, `dedupe`. `persistence_write_failed` only. The one camelCase *value* this app sends — it is a Swift case name, so renaming a case changes the analytics vocabulary. `AnalyticsNamesTests` pins the set. |
| `startup_stage` | String | `ContainerCreationFailure.Stage.rawValue`: `store_open`, `legacy_import`, `first_launch_seed`. `startup_failed` only. Says how far launch got, which is what separates "the store would not open" from "the store opened and a later stage failed" — only the first offers the destructive reset, so §3.6's ratio is meaningless unless filtered by it. As with `error_operation`, the Swift case names *are* the vocabulary; `AnalyticsNamesTests` pins the set. |
| `orientation` | String | `portrait` / `landscape`. Face-up/face-down are filtered out, not reported. |
| `new_value` / `old_value` | Bool | `analytics_consent_changed` only. |
| `time_since_first_eligible_bucket` | String | `<1d` / `<7d` / `<30d` / `30d+` between first eligibility and the request. `rating_prompt_requested` only. Bucketed: an exact interval on an event answers nothing the bucket does not, and the exact moments are on the profile (§9.3). |

Counts are sent **raw** rather than bucketed. Mixpanel handles numeric properties natively, and
`simple-recurring-budgets`'s bucketing is privacy-motivated — which would be incoherent here, given
that we send the checklist name.

### 9.2 Super properties

Registered on lazy SDK init, so they attach to every event including `app_opened`, and re-register
after a reset → re-opt-in cycle.

| Super property | Source |
| --- | --- |
| `app_version` | `CFBundleShortVersionString` |
| `app_build` | `CFBundleVersion` |
| `device_class` | `UIDevice.current.userInterfaceIdiom` → `phone` / `pad` |
| `locale` | `Locale.current.identifier` |
| `region` | `Locale.current.region?.identifier` — the device's **region setting**, not where the device is |
| `consent_jurisdiction` | `required` / `auto_optin` (§6.2) |

`SettingsManager.versionBuildString` combines version and build into a display string and appends
`- DEBUG` in debug builds. **Do not send it.** Version and build go separately so both can be
filtered on.

**`region` and `locale` are device settings, not positions.** Mixpanel's IP-derived `$region` is off
(§4.3), so `consent_jurisdiction` follows the setting the person chose, not where they are.

`consent_jurisdiction` is not cosmetic. The strict-jurisdiction cohort is silent until it opts in, so
reach and retention are systematically under-counted for that segment; without this property a
consent-driven measurement gap is indistinguishable from a real drop in usage.

`device_class` is near-constant given `TARGETED_DEVICE_FAMILY = 1` — it distinguishes an iPad running
the iPhone app from a real iPhone. It replaces the per-event `ui_idiom` property Flurry carried on
every rotation, which never varied within an install.

### 9.3 People properties

| People property | Set when |
| --- | --- |
| `first_seen_at` | `setOnce` on first identify |
| `last_app_open_at` | `set` on every `app_opened` |
| `analytics_opt_in_at` | On the opt-in transition |
| `checklists_count_bucket` | `0` / `1` / `2-3` / `4-7` / `8+`, recomputed on `checklists_viewed` — the list reappears after every creation and deletion, and `@Query` has not yet updated at the moment `checklist_created` fires |
| `rating_prompt_first_eligible_at` | `set` once, alongside `rating_prompt_eligible`. Lets retention be segmented by whether — and how soon after `first_seen_at` — someone reached the bar. **Absent for anyone who reached it while opted out** and opted in later: the stamp is one-shot and the consent gate dropped it, the same population caveat as `analytics_opt_in_at` below |
| `rating_prompt_last_requested_at` | `set` on every `rating_prompt_requested`. No outcome is stored: StoreKit reports none (§3.9) |

Bucketing on the **profile** while sending the raw count on **events** is consistent, not
contradictory: §9.1's "raw" argument is about event properties, and profiles are what cohorts are
built from, where coarse buckets are what you actually want. This is this app's one cohort signal.

**`analytics_opt_in_at` is absent on an auto-opt-in install that never touches the toggle.** This is
spec-consistent, not a gap: the property is set "on the opt-in transition" (§6.3), and an
auto-opt-in jurisdiction's default-on state is not a transition. Do not build a cohort on this
property expecting full population coverage — pair it with `consent_jurisdiction` if "when did this
person's data start flowing" needs an answer for every install, not just the ones that made an
explicit choice.

## 10. Build hygiene — **Built**

**The token is never a source literal.** The Flurry API key was hardcoded in `AnalyticsManager.swift`
for six years and is still in roughly 294 commits of this repo's history (issue #115). The mechanism
that prevents a repeat:

```
config/Secrets.xcconfig                    committed; PLACEHOLDER_* sentinels; ends with
                                           #include? "Secrets.local.xcconfig"
config/Secrets.local.xcconfig              GITIGNORED; the real tokens
config/Secrets.local.xcconfig.template     committed; what to copy
        ↓  baseConfigurationReference on the app target (Debug + Release)
Info.plist   MixpanelDevToken / MixpanelProdToken = $(MIXPANEL_DEV_TOKEN) / $(MIXPANEL_PROD_TOKEN)
        ↓  Bundle.main.object(forInfoDictionaryKey:)
AppConfig  →  MixpanelTokenSource.activeToken   (#if DEBUG picks dev vs prod)
```

The sentinel strings exist in **three** places that must stay in sync: `config/Secrets.xcconfig`,
`AppConfig.Placeholder`, and `scripts/verify_release_secrets.sh`. `AppConfigSentinelTests` guards the
Swift half.

**Validity is a shape check, not a blacklist.** Both `MixpanelTokenSource.isValidToken` and the ship
guard require **32 lowercase hex characters**. Comparing against the known sentinels was not enough:
the likeliest mistake is copying `Secrets.local.xcconfig.template` and forgetting to paste, which
leaves `your_32_char_prod_token_here` — neither empty nor a sentinel. That would have passed the ship
guard *and* satisfied `isConfigured`, initializing the SDK with a junk token that drops every event.
Shape-checking also rejects `$(inherited)` and a sentinel with trailing garbage, in one rule.

**`isConfigured` checks only the active token**, not both. Requiring both (as
`simple-recurring-budgets` does) means a maintainer who fills in the prod token but leaves dev at
its placeholder gets a green ship guard and a Release build where `isConfigured` is false — zero
analytics, everything green. The ship guard checks only the prod token for the same reason; the two
now agree.

**A fresh clone works.** No local secrets file means the token resolves to an empty string (Xcode
substitutes empty for an undefined build setting), `isConfigured` returns false, and the app falls
back to the console client. It builds, launches, and passes its tests.

**The ship guard.** `scripts/verify_release_secrets.sh` refuses a Release archive carrying the
placeholder prod token or missing the local file. It runs from three places: `make verify-secrets`
(the manual pre-archive check), `fastlane/lib/release_build.rb`'s release-candidate lane, and an
Xcode "Verify release secrets" run-script phase restricted to install/archive builds via
`runOnlyForDeploymentPostprocessing`. Because `ENABLE_USER_SCRIPT_SANDBOXING = YES`, that phase
declares all three files as `inputPaths` or the sandbox denies the reads. Note Xcode's `SRCROOT` is
`checklists/`, one level below the repo root, hence the `$(SRCROOT)/../` paths — another divergence
from `simple-recurring-budgets`, whose project sits at its repo root.

Inside the build phase the guard prefers the **resolved** `$MIXPANEL_PROD_TOKEN` from the build
environment over parsing the repo file, falling back to the file for `make verify-secrets`. Checking
only the file fails open: if `baseConfigurationReference` were ever dropped from the project, the
xcconfig would still hold a real token while Info.plist got an empty one — a green guard on a build
with no working token.

It is deliberately **not** part of `make gate` or lefthook: a fresh clone has no local secrets file,
and failing the everyday gate on that would be wrong.

**Gitleaks proves less than it looks like.** The default ruleset never caught the Flurry key — a bare
20-character alphanumeric with no adjacent keyword matches nothing. `.gitleaks.toml` adds a
Mixpanel-token rule as a second line of defense. It carries **no allowlist**: an earlier draft
exempted `config/Secrets.xcconfig` by path, which blinded the rule to the one committed file whose
key names most invite a paste. The placeholders need no exemption — they are not 32 hex characters,
so they cannot match. The real defense remains the `.gitignore` entry.

**Export compliance.** `Info.plist` sets `ITSAppUsesNonExemptEncryption = false`, which is what
skips App Store Connect's per-upload export questionnaire. It is correct only while the app's
encryption is entirely OS-provided — HTTPS via `URLSession` and CloudKit. Giving Realm an
`encryptionKey`, or adopting any proprietary crypto, means flipping this key to `true` and
supplying `ITSEncryptionExportComplianceCode`.

**Privacy manifest.** `checklists/checklists/PrivacyInfo.xcprivacy` declares `NSPrivacyTracking =
false`, no tracking domains, one accessed-API reason (`UserDefaults`, `CA92.1`), and **four**
collected data types — all linked, purpose Analytics, none used for tracking:

| Type | Covers |
| --- | --- |
| Product Interaction | Screen views, counts, action events |
| Other User Content | `checklist_name` (§4.4) |
| Device ID | The persisted `distinct_id` (§5) — app-generated, but still a per-install identifier sent to a third party, and the reason everything else is *linked* |
| Other Diagnostic Data | The `error_*` properties on the failure events |

It needs no project-file entry — the synchronized root group adds it to the Resources phase
automatically.

## 11. Boundary with `OSLog`

`Logging/AppLoggers.swift` is the **diagnostics** channel; analytics is the **product** channel. They
are architecturally independent and **never feed each other**, which is why they live in separate
directories.

| Concern | Routed to |
| --- | --- |
| Operational failure a developer must diagnose | `OSLog` (`AppLog.persistence` / `.cloudKit` / `.bootstrap`) |
| Product behaviour worth aggregating | Analytics |
| A failure that is *both* | **Both, as sibling calls** — neither derives its arguments from the other |

`OSLog` needs no backend, no SDK, and no network. It reaches the logging daemon synchronously, so it
survives the `fatalError` that follows it — an analytics event queued for HTTP does not. It is also
**not consent-gated**, which is what makes it the complete record when §7.3's gating drops an error
event.

**Do not** route `OSLog` output into Mixpanel, and **do not** delete `OSLog` calls now that analytics
work again. They answer different questions and have different durability.

## 12. Dashboards — **Built**

Boards live in Mixpanel and **Mixpanel is the source of truth** — the table below is a planning
record and will drift, because boards get edited by hand. On a mismatch, Mixpanel wins; update this
section to match.

| Project | Receives events from | ID |
| --- | --- | --- |
| `reChecklist App - Prod` | Release builds — App Store and TestFlight | 4062256 |
| `reChecklist App - Dev` | Debug builds — Simulator and developer devices | 4062257 |

Both are on the Growth plan, so there is no saved-report cap to work around. The Mixpanel MCP server
is connected, so boards can be created and edited directly.

`notes_length` is deliberately **not** charted. It is captured on `checklist_viewed` and available for
ad-hoc queries, but a distribution of note lengths answers no question in §3 that
`items_with_notes_count` does not answer better.

Board conventions: write for a human reader — short, plain names about the **behaviour** shown, with
one `§3.x` reference for traceability. No ticket IDs, no "built via MCP", no filter mechanics in
names. One short framing text card per board. **Never** put a §4.3 deny-listed field into a query.

Prod is canonical. Dev carries the same set and doubles as the smoke-test surface for confirming that
events arrive with the right properties before a release.

## 13. Test strategy

Test conventions: AGENTS.md §"Build and test".

Contracts — built except where marked:

8. **Consent ordering** — toggle-off produces exactly `[track(consent_changed, false), reset]` and
   leaves the flag false; toggle-on sets the flag before tracking; decline sends nothing but marks
   the choice explicit.
9. Lazy init, verified two ways against the **real** `MixpanelAnalyticsClient` (`MixpanelClientGateTests`):
   a never-initialized client's `reset()` and its people-property setters cannot themselves reach
   `Mixpanel.initialize` — the regression that would matter most, since `reset()` always passes
   through the consent gate; and `ConsentGatedAnalyticsClient` wrapping a real client with
   `isOptedIn: { false }` leaves the SDK uninitialized after repeated `track`/`identify` calls.
   **Not separately asserted:** that an opted-in `track` initializes the SDK exactly once — doing so
   would require actually calling `Mixpanel.initialize`, which contacts `api.mixpanel.com` even with
   a fake token and leaves real artifacts on disk. That half is covered by the manual simulator
   verification in §5 instead.
17. Test-launch settings isolation — every automated launch gets a fresh in-memory settings store.
    In Debug screenshot launches, the combination of a recognized test marker, screenshot seed
    JSON, and a nonempty screenshot locale preseeds an explicit opt-out before
    `AnalyticsSettings` initializes. Ordinary test launches retain absent consent, production uses
    its persistent defaults, and Release contains no screenshot consent-seeding path. The strict
    region UI regression keeps the ordinary first-run presentation case and proves a localized
    screenshot fixture does not present it.

The remaining contracts, including `RatingPromptCoordinatorTests`, map 1:1 onto the suites in
`checklistsTests/`; read the suite names. Deliberately uncovered: no shown/resolved event exists to
assert on for the rating prompt (§3.9).

## 15. Published disclosures

- **Privacy policy** — <https://jimmynotjames.github.io/checklists/privacy.html>, served from this
  repo's `gh-pages` branch (`privacy.html`). Names Mixpanel as the processor. Refs #190.
- **Nutrition label** — declares the same four types as `PrivacyInfo.xcprivacy`, each Linked,
  purpose Analytics, not tracking.

The policy URL is carried in `SettingsView.swift` and `fastlane/metadata/en-US/privacy_url.txt`.

**Do not push the App Store listing yet.** `privacy_url.txt` is updated in the repo but must not
reach App Store Connect until the first build carrying the Mixpanel SDK is submitted; the listing
still points at the 2019 page, which is correct while `v1.1.0` collects nothing. Run
`push_metadata` as part of the release that ships the SDK.

Three things about the policy are deliberate. Do not "fix" them:

1. **It is generic.** It clones the TermsFeed document generated for Wren, and does not
   enumerate the §10 events, the `checklist_name` exception (§4.4) or the §6.2 consent model. A
   vetted template beats a hand-written inventory. If that is ever revisited, §4 and §6 are the
   input a rewrite would draw on.
2. **One clause is app-specific:** it names the Settings toggle as the way to turn analytics off.
   The template's only opt-out was `mixpanel.com/optout`, which does nothing for a native SDK.
3. **CCPA categories A and F are "Collected: Yes"**; B–E and G–L are "No". `distinct_id` is an
   identifier, and Mixpanel sees the request IP regardless of `useIPAddressForGeoLocation`.

Where the policy departs from Wren's wording, it is because the template asserted collection,
sale or sharing this app does not do. See the `gh-pages` history for what changed and why.

**Enforcement.** Apple documents no automated label-vs-manifest check; what is gated is manifest
schema validity — a malformed `.xcprivacy` is rejected at upload. The label is a self-attestation,
editable at any time with no new binary; the manifest only changes in a new build. Fix the label
when it drifts, converge the manifest next release.

## 16. Deviations from `simple-recurring-budgets`

`simple-recurring-budgets` is the reference implementation. Every difference below is deliberate,
with a reason.

| `simple-recurring-budgets` | Here | Why |
| --- | --- | --- |
| `NSUbiquitousKeyValueStore` for opt-in, `distinct_id` and the rating-prompt counters | `UserDefaults.standard` behind a `KeyValueStore` seam | No `ubiquity-kvstore-identifier` entitlement (§5) |
| Rating prompt fed by an Add-mode expense log at a non-deficit moment; requested after the Add Expense sheet dismisses | Fed by an item check-off; requested once the person is back on the checklists list | Checking an item is this app's one core action, and the checklist screen is a push, not a sheet (§8) |
| `time_since_first_eligible_bucket` top value `≥30d` | `30d+` | ASCII, so it can be typed into a Mixpanel filter without hunting for the glyph |
| All consent copy in `Localizable.xcstrings` | Same | Both keep consent copy in the catalog; it is translated into all 50 locales and carries translator comments (`core-docs/localization-spec.md`) |
| Sheet triggered after the first `budget_created` | After the first `checklist_viewed` on an existing checklist | Sample checklists are seeded, so creation may never happen (§6.2) |
| `IS_TESTING` env var only | `-UITests1` **or** `IS_TESTING` | The XCUITest bundle passes only the launch argument (§7.1) |
| Analytics and `OSLog` both in `Logging/` | Analytics in `Analytics/`, `OSLog` in `Logging/` | Both docs insist the channels are independent — let the directories say so (§11) |
| One collected data type; empty accessed-API array | Four data types; `UserDefaults` declared | `checklist_name` is user content; this app uses `UserDefaults` (§10) |
| `$(SRCROOT)/config/…` | `$(SRCROOT)/../config/…` | The Xcode project sits one level below the repo root (§10) |
| `budgets_count_bucket` as a super property | `checklists_count` raw per-event; bucket on the profile | The count already rides on the most frequent event (§9) |
| A protocol, but ordering logic inline in bindings | Ordering extracted into a testable controller | So the §6.3 contract tests real code (§13) |
| `isConfigured` requires **both** tokens | Requires only the **active** token | Requiring both ships a green, analytics-dead Release when only dev is unfilled (§10) |
| `KeyValueStore` protocol lives in `Settings/` | Lives in `Analytics/` | Nothing else in this app uses the seam; analytics owns it |

**Known trade-off, deliberately kept.** Both `MixpanelDevToken` and `MixpanelProdToken` ship in every
build's Info.plist, so the dev project's token is extractable from a release IPA and vice versa. A
single `MIXPANEL_TOKEN` key resolved per-configuration in the xcconfig would ship only one. This
follows `simple-recurring-budgets` as-is because Mixpanel project tokens are client-side
credentials — the active one is extractable from any shipped app regardless — so the marginal
exposure is the ability to send junk events to the *other* project. Revisit if that ever happens.

## 17. Keeping this current

When the analytics surface changes — a new event, a property added to or removed from an event, a new
value in a categorical property, a new super or people property, a jurisdiction added or removed —
**update this file in the same change**. The catalogs in §8 and §9 are the only record of what the
app is supposed to emit; the name constants are the only record of what it does emit.

The strict-opt-in region set lives only in `ConsentJurisdiction.swift` now (§6.2) — there is no
separate list here to keep in sync.
