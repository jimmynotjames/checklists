# Analytics Spec

| Field        | Value      |
| ------------ | ---------- |
| Version      | 1.2        |
| Last Updated | 2026-09-11 |
| Author/Owner | Jimmy Ho   |

> This is the canonical description of what this app measures, what it refuses to measure, and
> how the measurement is wired. It supersedes `analytics-design.md`, which was the pre-implementation
> tracking plan written while analytics were stubbed. Where this document and the code disagree, one
> of them is a bug — say which in the PR.
>
> The sibling **`budgets1`** repo has the reference Mixpanel implementation
> (`simple-recurring-budgets/Logging/`, `docs/analytics-spec.md`). This app's conventions were
> deliberately aligned to it; §16 records every place they intentionally diverge.

**Implementation status.** The token/secrets mechanism, the privacy manifest, the Mixpanel projects
and their dashboards (§12), this document, the **client protocol with all 16 call sites migrated**
(§7), and the **locale-aware consent flow** (§6) are built. Only the Mixpanel SDK itself is
**pending** — tracked as the final PR in the sequence that began with `analytics-secrets-and-spec`.
Section headers below say "Built" or "Pending" where it matters. Nothing in this app sends
analytics anywhere until that PR lands; the consent UI exists and the opt-in flag is tracked, but
today it gates only `ConsoleAnalyticsClient`, which prints in DEBUG and does nothing in Release.

---

## 1. Status and scope

Flurry Analytics 11.2.0 instrumented this app from 2019 until it was removed at end of life. Every
`log*` call site survived that removal and has been firing into a no-op ever since. **Mixpanel is the
replacement.**

| Decision | Value |
| --- | --- |
| Vendor | Mixpanel (`mixpanel-swift`, SPM, pinned `upToNextMajorVersion` from 6.5.0) |
| Projects | `reChecklist App - Prod` (4062256) and `reChecklist App - Dev` (4062257), selected by `#if DEBUG` |
| Plan | Growth — unlimited saved reports, $0/month under the 1M-events/month allotment |
| Automatic events | **Off.** `trackAutomaticEvents: false` |
| Crash reporting | **None.** Mixpanel does not do it, and no third-party crash SDK is taken on. Xcode Organizer only. |
| App Tracking Transparency | **Out of scope and staying there.** No IDFA, no ATT prompt. |
| Sessions | Derived server-side from the `app_opened` event stream. Mixpanel has no `startSession`. |

Two Flurry capabilities are **gone, deliberately**: automatic session tracking (replaced by an
explicit `app_opened` on every foreground) and crash reporting. §14 records the full mapping for
anyone reading a historical Flurry export.

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
7. **No engagement-pressure events.** This app does not measure how to nag people.
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
| 3.5 | Do people reset checklists (reuse) or just make new ones (disposable)? | `checklist_reset` vs `checklist_created` |
| 3.6 | How often does the store fail to open in the field, and how often is that unrecoverable? | `startup_failed` / `startup_store_reset` |
| 3.7 | Does anyone rotate the device? (The orientation-notification cost is only worth paying if so.) | `orientation_changed` |
| 3.8 | What share of installs opt out, and how does that differ by jurisdiction? | `analytics_consent_changed`, `consent_jurisdiction` |

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
| `error` (truncated to 127 chars) | Yes | SwiftData/CloudKit error descriptions: a path and a code, not user content. |
| App version, build, locale, region, device class | Yes | Standard environment context (§9.2). |
| A generated `distinct_id` UUID | Yes | Random, app-generated, not derived from any device or Apple identifier (§5). |

### 4.3 Deny-list

| Field / category | Denied | Rationale |
| --- | --- | --- |
| **Item names** | Never | The bulk of user content. `items_count` is sufficient. |
| **Item notes** | Never | Free text. `items_with_notes_count` is sufficient. |
| **Checklist notes** | Never | Free text. `notes_length` is sufficient. |
| Any Apple identifier (IDFA, IDFV, device name) | Never | No tracking, no ATT (§1). |
| iCloud account identifiers or CloudKit record names | Never | Identity is the app-generated UUID only. |
| Any `OSLog` message text | Never | Separate channel (§11). |
| Contents of the Realm import (legacy data) | Never | Only the import's success/failure reaches analytics, via `startup_failed`. |

### 4.4 Accepted-risk exception: `checklist_name`

`checklist_viewed` sends the checklist's name verbatim, truncated to 127 characters. This is a
deliberate, eyes-open decision mirroring the way `budgets1` allow-lists `budget_name`. **Question
§3.2 — what do people actually make checklists for? — is not answerable any other way**, and it is
the single most valuable product question this app has.

Constraints on the exception, all of which are load-bearing:

- It is the **only** free-text property this app transmits. Everything else in §4.3 stays denied.
- Adding any other user-content property is a **new decision**, not covered by this precedent.
- It sits **behind the consent gate**. This is why the first-run consent sheet is triggered by the
  first `checklist_viewed` rather than at launch or on first write (§6.2) — the gate is placed
  immediately before the riskiest event can first fire.
- It is declared in `PrivacyInfo.xcprivacy` as `NSPrivacyCollectedDataTypeOtherUserContent`, which is
  the reason this app's privacy manifest differs from `budgets1`'s (§16).
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
deviation from `budgets1`, forced by a real constraint: `checklists.entitlements` declares CloudKit
but **not** `com.apple.developer.ubiquity-kvstore-identifier`, so the iCloud key-value store would
not sync. Adding that entitlement means a capability change, a regenerated provisioning profile, and
an App Store Connect edit — a bad thing to bundle into the change that also introduces a third-party
SDK.

Accepted consequences:

- The consent decision and the `distinct_id` are **per-device, not per-person**. Someone using the
  app on an iPhone and an iPad counts as two. Given `TARGETED_DEVICE_FAMILY = 1`, this is rare.
- It is arguably the more privacy-conservative option, since nothing about the install leaves the
  device's own defaults.
- Migrating later is a one-line change to the store injected into `AnalyticsSettings`, plus a
  read-through migration, precisely because access goes through the `KeyValueStore` seam.

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

| Jurisdiction | Region codes | Basis |
| --- | --- | --- |
| European Union | AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE | GDPR + ePrivacy Directive |
| EEA (non-EU) | IS, LI, NO | GDPR via the EEA agreement |
| United Kingdom + Crown Dependencies | GB, GG, JE, IM | UK GDPR + PECR |
| Switzerland | CH | revFADP |
| South Korea | KR | PIPA |
| China (mainland) | CN | PIPL |
| Brazil | BR | LGPD |
| Turkey | TR | KVKK |
| Thailand | TH | PDPA |
| Canada | CA | Quebec Law 25, applied CA-wide as a pragmatic simplification |

An **unknown region resolves to `.required`** — the conservative default. This is the easiest
behaviour to regress and is covered by a test.

**The resolved default is never written to the store.** Whether a choice has been made explicitly is
exactly `store.object(forKey:) != nil`, and that is what gates the sheet. Writing the default at
launch would make every install look like it had already decided.

**Trigger: the first `checklist_viewed` on an existing (pushed) checklist.** `budgets1` triggers its
sheet after the first `budget_created`; that does not port, because **this app seeds sample
checklists on first launch**, so a person may never create one and could use the app indefinitely
without being asked. Opening a checklist is this app's core loop, always happens, and happens after
the product has shown its value. Decisively, it is the moment `checklist_name` (§4.4) would first be
transmitted.

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

| Condition | Client |
| --- | --- |
| Running tests (`-UITests1` launch arg **or** `IS_TESTING` env var) | `ConsoleAnalyticsClient` |
| Tokens are still placeholder sentinels (fresh clone) | `ConsoleAnalyticsClient` |
| Otherwise | `MixpanelAnalyticsClient` |

Until the SDK lands, the selection returns `ConsoleAnalyticsClient` unconditionally — the shape is
in place, the third row is not yet reachable.

The test guard delegates to the existing `LaunchModeContainerFactory.isRunningTests`, which already
handles **both** signals. `budgets1` checks only its `IS_TESTING` env var; ported literally, that
would let this repo's UI-test runs send real events, because the XCUITest bundle passes only the
launch argument.

`ConsoleAnalyticsClient` prints in DEBUG and does nothing in Release. It is also the environment
default, so a SwiftUI preview or a view constructed in isolation never needs a real client.

### 7.2 Launch and consent-transition ordering

**Cold launch.** Build the client → install it for the pre-environment call sites (§7.3) → construct
the startup model → inject the client into the environment for every startup phase → fire
`app_opened` once the scene becomes active.

**SDK initialization is lazy.** `Mixpanel.initialize` is not called in the client's initializer. It
happens on the first `track` that passes the opt-in guard, and that same path registers the super
properties and identifies the person. An install that is opted out therefore never constructs a
Mixpanel instance and never opens a socket.

**After `reset()`** the instance is discarded. A later opt-in re-runs the full lazy init, which
re-registers super properties and re-identifies — this is why super-property registration lives
inside the initializer rather than at a single launch call site.

### 7.3 Reaching the client from non-SwiftUI code

**This is the part most likely to be got wrong.** Three call sites run before any SwiftUI environment
exists, and two more are in UIKit.

**The UIKit checklist screen** (`ChecklistViewController`) receives the client as a stored property,
assigned by its SwiftUI host in `makeUIViewController`. This mirrors two injections already in that
file (`onRequestDismiss`, `saveItemMove`), and it defaults to the console client so pure-UIKit
construction and previews keep working.

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
point of having them in one place. `budgets1` does the same, for the same reason. A new constant
without `nonisolated` compiles until the first model extension tries to use it.

**Consent interacts with this and it is not a bug.** These three error events are consent-gated like
everything else, so in strict-opt-in jurisdictions they are dropped on exactly the launch where they
would matter most. That is correct under §6.2's no-retroactive-replay rule, and it is precisely why
the `OSLog` channel (§11) remains the complete record. Do not "fix" it by exempting them.

## 8. Event catalog

All names are flat `snake_case`, `noun_pastTenseVerb`. 16 events.

| Event | Fires when | Properties | Answers |
| --- | --- | --- | --- |
| `app_opened` | Cold launch, **and** every return from background | — (super properties carry context) | §3.1 |
| `checklists_viewed` | The checklists list appears | `checklists_count` | §3.3 |
| `checklist_viewed` | A checklist is opened | `checklist_name`, `notes_length`, `items_count`, `items_with_notes_count` | §3.2, §3.3, §3.4 |
| `settings_viewed` | Settings appears | — | §3.1 |
| `main_menu_viewed` | The main menu appears | — | §3.1 |
| `checklist_created` | A checklist is created | — | §3.5 |
| `checklist_reset` | All items in a checklist are unchecked | — | §3.5 |
| `rate_app_tapped` | "Rate in App Store" tapped | — | §3.1 |
| `feedback_tapped` | "Send feedback" tapped (main menu **or** the failure screen) | — | §3.1 |
| `privacy_policy_tapped` | The privacy policy is opened | — | §3.1 |
| `orientation_changed` | Device rotates portrait ↔ landscape | `orientation` | §3.7 |
| `persistence_fatal_error` | The store cannot be opened at all | `error` | §3.6 |
| `persistence_write_failed` | A SwiftData save throws | `error` | §3.6 |
| `startup_failed` | Launch could not produce a usable store, so the retry screen was shown | `error` | §3.6 |
| `startup_store_reset` | "Start over fresh" chosen on that screen, deleting this device's stores | — | §3.6 |
| `analytics_consent_changed` | The consent toggle or first-run sheet changes the setting | `new_value`, `old_value` | §3.8 |

**`app_opened` fires on "`.active` having seen `.background`", not "`.active` preceded by
`.background`".** iOS delivers `.inactive` on the way back in, so a real foreground return arrives
as `background → inactive → active`. Testing only the immediately preceding phase misses every
foreground return and silently reduces the event to cold launches — which would put every session,
reach and retention number on this app's dashboards on a cold-launch-only basis. `budgets1`'s
`AppOpenTracker`, which this was ported from, has that bug. Verified here on a simulator: one cold
launch plus two background/foreground cycles produces exactly three events, and an `.inactive`
detour with no `.background` in it produces none.

**`startup_failed` is the one to watch.** It is the only signal that someone was shown a failure
screen instead of their checklists, and its count measures how often the store cannot be opened in
the field. Note that no data has been lost when it fires — the store simply would not open, and the
legacy Realm file is still untouched on disk, with the import retried next launch. See
[`persistence-design.md`](persistence-design.md).

**The error events are diagnostics, not product signals.** `persistence_fatal_error` fires
immediately before a `fatalError`, so Mixpanel may never flush it. Treat any count it reports as a
floor, not a total — and see §11 for where the real record lives.

## 9. Property catalog

### 9.1 Per-event properties

| Property | Type | Values / notes |
| --- | --- | --- |
| `checklists_count` | Int | Raw, not bucketed. |
| `checklist_name` | String | **Raw user content**, truncated to 127 chars. See §4.4. |
| `notes_length` | Int | Character count of the checklist's notes. 0 when absent. |
| `items_count` | Int | |
| `items_with_notes_count` | Int | Counts items whose notes are non-nil *and* non-empty. |
| `error` | String | Truncated to 127 characters. |
| `orientation` | String | `portrait` / `landscape`. Face-up/face-down are filtered out, not reported. |
| `new_value` / `old_value` | Bool | `analytics_consent_changed` only. |

Counts are sent **raw** rather than bucketed. Mixpanel handles numeric properties natively, and
`budgets1`'s bucketing is privacy-motivated — which would be incoherent here, given that we send the
checklist name.

### 9.2 Super properties

Registered on lazy SDK init, so they attach to every event including `app_opened`, and re-register
after a reset → re-opt-in cycle.

| Super property | Source |
| --- | --- |
| `app_version` | `CFBundleShortVersionString` |
| `app_build` | `CFBundleVersion` |
| `device_class` | `UIDevice.current.userInterfaceIdiom` → `phone` / `pad` |
| `locale` | `Locale.current.identifier` |
| `region` | `Locale.current.region?.identifier` |
| `consent_jurisdiction` | `required` / `auto_optin` (§6.2) |

`SettingsManager.versionBuildString` combines version and build into a display string and appends
`- DEBUG` in debug builds. **Do not send it.** Version and build go separately so both can be
filtered on.

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

Bucketing on the **profile** while sending the raw count on **events** is consistent, not
contradictory: §9.1's "raw" argument is about event properties, and profiles are what cohorts are
built from, where coarse buckets are what you actually want. This is this app's one cohort signal.

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

**`isConfigured` checks only the active token**, not both. Requiring both (as `budgets1` does) means a
maintainer who fills in the prod token but leaves dev at its placeholder gets a green ship guard and a
Release build where `isConfigured` is false — zero analytics, everything green. The ship guard checks
only the prod token for the same reason; the two now agree.

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
from `budgets1`, whose project sits at its repo root.

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

**Privacy manifest.** `checklists/checklists/PrivacyInfo.xcprivacy` declares `NSPrivacyTracking =
false`, no tracking domains, one accessed-API reason (`UserDefaults`, `CA92.1`), and **four**
collected data types — all linked, purpose Analytics, none used for tracking:

| Type | Covers |
| --- | --- |
| Product Interaction | Screen views, counts, action events |
| Other User Content | `checklist_name` (§4.4) |
| Device ID | The persisted `distinct_id` (§5) — app-generated, but still a per-install identifier sent to a third party, and the reason everything else is *linked* |
| Other Diagnostic Data | The `error` property on the failure events |

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

**Built** — five boards, 12 report tiles, in **both** projects.

| Board | Tiles as shipped | Answers |
| --- | --- | --- |
| Reach | Daily active people; Monthly active people; Does anyone rotate the device (by `orientation`) | §3.1, §3.7 |
| Checklist composition | What people make checklists for (by `checklist_name`); How many checklists people keep (by `checklists_count`); How long checklists get (by `items_count`); Are notes actually used (by `items_with_notes_count`); Reuse or start over (`checklist_reset` vs `checklist_created`) | §3.2–§3.5 |
| Retention | Come back and open a checklist — born `app_opened`, returning `checklist_viewed`, daily curve | §3.1 |
| Startup failures | Failed launches vs. fresh starts (`startup_failed` vs `startup_store_reset`); Store errors in the field (`persistence_fatal_error`, `persistence_write_failed`) | §3.6 |
| Consent | Opt-ins and opt-outs by jurisdiction (`consent_jurisdiction` × `new_value`) | §3.8 |

Every board opens with a one-line framing card. The Startup-failures card states the floor-not-total
caveat from §8, and the Consent card warns that the opt-in-required segment is under-counted on every
other board — both are things a reader would otherwise misread. Boards show no data until the
instrumentation PRs land; the definitions are correct and populate as events arrive.

Each project also carries Mixpanel's auto-generated **🌱 Starter Board**. It is owned by the Mixpanel
system user, not by us; delete it if it clutters the list.

`notes_length` is deliberately **not** charted. It is captured on `checklist_viewed` and available for
ad-hoc queries, but a distribution of note lengths answers no question in §3 that
`items_with_notes_count` does not answer better.

Board conventions: write for a human reader — short, plain names about the **behaviour** shown, with
one `§3.x` reference for traceability. No ticket IDs, no "built via MCP", no filter mechanics in
names. One short framing text card per board. **Never** put a §4.3 deny-listed field into a query.

Prod is canonical. Dev carries the same set and doubles as the smoke-test surface for confirming that
events arrive with the right properties before a release.

## 13. Test strategy

The suite is 100% XCTest, in the house pattern (`nonisolated final class … : XCTestCase` with
`@MainActor` on each test method, forced by `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). **Do not
introduce Swift Testing** — that is a `budgets1` convention that does not apply here.

`SpyAnalyticsClient` records an **ordered list of calls**, not parallel per-method arrays. This
matters: it is what lets §6.3's ordering contract be asserted against real production code rather
than re-simulated inside the test body.

Contracts — **built** except where marked, which land with the consent and SDK changes:

1. `truncated(_:)` — under, at, and over 127 chars, and no splitting of a multi-scalar emoji.
2. `ConsentJurisdiction` — every strict code maps to `.required`; representative others to
   `.autoOptin`; **`nil` → `.required`**.
3. Opt-in defaults — strict region → `false`, elsewhere → `true`, and **the resolved default is not
   written to the store**; an explicit value overrides the locale default.
4. `distinct_id` — generated once, persisted, stable across instances, parses as a UUID.
5. `AppOpenTracker` — fires on first `.active` and on `.background → .active`; **not** on
   `.inactive → .active` (the notification shade and app switcher are not opens).
6. `isValidToken(_:)` — the 32-lowercase-hex shape rule, without touching `Bundle.main`.
7. Placeholder sentinels — non-empty, distinct, and not mistakable for a real token.
8. **Consent ordering** — toggle-off produces exactly `[track(consent_changed, false), reset]` and
   leaves the flag false; toggle-on sets the flag before tracking; decline sends nothing but marks
   the choice explicit.
9. Lazy init — an opted-out client never initializes the SDK however many `track` calls it receives;
   flipping to opted-in initializes exactly once. *(pending — SDK)*
10. Name constants — all distinct, all `snake_case`.
11. Orientation mapping — portrait/landscape values, `nil` for face-up/face-down.
12. Checklist view properties — counts, notes length for nil notes, name truncation.
13. `persistence_fatal_error` and `startup_failed`, via the injectable container factory and
    startup coordinator — including that a *successful* launch emits nothing. (The save-helper path
    is injectable too, but a real SwiftData save only fails on a full or damaged disk, which a unit
    test cannot arrange.)
14. `StoreReset` leaves the analytics keys alone (§5).
15. The client-selection predicate covers **both** `-UITests1` and `IS_TESTING` (§7.1). *(pending — SDK)*

Tests are opt-in and not gated (`make test-unit`). Read pass/fail from the `.xcresult`, never from a
piped exit code — see AGENTS.md.

## 14. Flurry-era history

Kept because it is the only record of what old Flurry exports mean. Renaming was free: the Flurry
data is not migrating, so there was no continuity to preserve.

| Current event | Flurry name |
| --- | --- |
| `app_opened` | *(none — Flurry auto-tracked sessions)* |
| `checklists_viewed`, `checklist_viewed`, `settings_viewed`, `main_menu_viewed`, `orientation_changed` | unchanged |
| `checklist_created` | `create_new_checklist` |
| `checklist_reset` | `reset_checklist` |
| `rate_app_tapped` | `rate_in_app_store` |
| `feedback_tapped` | `send_feedback` |
| `privacy_policy_tapped` | `view_privacy_policy` |
| `persistence_fatal_error` | `realm/fatal_error` |
| `persistence_write_failed` | `realm/write_error` |
| `startup_failed`, `startup_store_reset`, `analytics_consent_changed` | *(new)* |

| Current property | Flurry key |
| --- | --- |
| `checklists_count` | `num_checklists` |
| `checklist_name` | `name` |
| `notes_length` | `notesLength` (the one camelCase key in the old catalog) |
| `items_count` | `num_items` |
| `items_with_notes_count` | `num_items_with_notes` |
| `error`, `orientation` | unchanged |
| `device_class` (super) | was the per-event `ui_idiom` |

Slashes were dropped from the Realm event names and the `realm/*` prefix became `persistence_*` so
the events survive a persistence-layer swap — which they since have.

Flurry also had `withCrashReporting(true)`, `withLogLevel`, and vendored `FlurryConsent` /
`FlurryCCPA` objects that this app never actually used.

## 15. Published disclosures — **action needed outside this repo**

Both were written for Flurry-era collection, are currently wrong in the "collects nothing" direction,
and will be wrong in the other direction once Mixpanel ships:

- **The privacy policy** linked from Settings is externally hosted (termsfeed). It must describe
  Mixpanel analytics, the `checklist_name` exception (§4.4), and the opt-out.
- **The App Store Connect privacy nutrition label** must match `PrivacyInfo.xcprivacy` — all four
  types: Product Interaction, Other User Content, Device ID, and Other Diagnostic Data. All Linked,
  purpose Analytics, **not** used for tracking.

Neither lives in this repo, so neither can be fixed by a PR here. Do both when the Mixpanel PR ships.

## 16. Deviations from `budgets1`

`budgets1` is the reference implementation. Every difference below is deliberate, with a reason.

| `budgets1` | Here | Why |
| --- | --- | --- |
| `NSUbiquitousKeyValueStore` for opt-in and `distinct_id` | `UserDefaults.standard` behind a `KeyValueStore` seam | No `ubiquity-kvstore-identifier` entitlement (§5) |
| All consent copy in `Localizable.xcstrings` | English string literals | No localization infrastructure at all; five keyed strings among ~200 literals is worse than either standard. Follow-up issue. |
| Sheet triggered after the first `budget_created` | After the first `checklist_viewed` on an existing checklist | Sample checklists are seeded, so creation may never happen (§6.2) |
| `IS_TESTING` env var only | `-UITests1` **or** `IS_TESTING` | The XCUITest bundle passes only the launch argument (§7.1) |
| Swift Testing | XCTest | The whole suite is XCTest (§13) |
| Analytics and `OSLog` both in `Logging/` | Analytics in `Analytics/`, `OSLog` in `Logging/` | Both docs insist the channels are independent — let the directories say so (§11) |
| One collected data type; empty accessed-API array | Two data types; `UserDefaults` declared | `checklist_name` is user content; this app uses `UserDefaults` in four places (§10) |
| `$(SRCROOT)/config/…` | `$(SRCROOT)/../config/…` | The Xcode project sits one level below the repo root (§10) |
| `budgets_count_bucket` as a super property | `checklists_count` raw per-event; bucket on the profile | The count already rides on the most frequent event (§9) |
| A protocol, but ordering logic inline in bindings | Ordering extracted into a testable controller | So the §6.3 contract tests real code (§13) |
| `isConfigured` requires **both** tokens | Requires only the **active** token | Requiring both ships a green, analytics-dead Release when only dev is unfilled (§10) |
| Ship guard blacklists the sentinel string | Ship guard validates token **shape** | A straight copy of the template passes a blacklist (§10) |
| `KeyValueStore` protocol lives in `Settings/` | Lives in `Analytics/` | Nothing else in this app uses the seam; analytics owns it |

**Known trade-off, deliberately kept.** Both `MixpanelDevToken` and `MixpanelProdToken` ship in every
build's Info.plist, so the dev project's token is extractable from a release IPA and vice versa. A
single `MIXPANEL_TOKEN` key resolved per-configuration in the xcconfig would ship only one. This
follows `budgets1` as-is because Mixpanel project tokens are client-side credentials — the active one
is extractable from any shipped app regardless — so the marginal exposure is the ability to send junk
events to the *other* project. Revisit if that ever happens.

## 17. Keeping this current

When the analytics surface changes — a new event, a property added to or removed from an event, a new
value in a categorical property, a new super or people property, a jurisdiction added or removed —
**update this file in the same change**. The catalogs in §8 and §9 are the only record of what the
app is supposed to emit; the name constants are the only record of what it does emit.

The region list in §6.2 and the region set in `ConsentJurisdiction.swift` must be edited together.

---

## Appendix A. Revision history

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.2 | 2026-09-11 | Jimmy Ho | Consent flow built (#PR3): `ConsentJurisdiction`, `AnalyticsSettings`, the testable `AnalyticsConsentController`, the first-run sheet gated on the first pushed `checklist_viewed`, and the always-on Settings toggle. Flipped §13's consent contracts from pending. Corrected §10's stale "no Fastlane here" claim and removed the now-agreeing Fastlane deviation row from §16 — both drifted true after Fastlane landed on `main`. |
| 1.1 | 2026-09-09 | Jimmy Ho | Client protocol built and all 16 call sites migrated off the static facade (#153). Recorded the three non-SwiftUI injection points and the `ChecklistsApp.init()` ordering requirement in §7.3, and the nonisolated-constants requirement that SwiftData model extensions impose. `AnalyticsManager` deleted. |
| 1.0 | 2026-09-09 | Jimmy Ho | Initial spec, superseding `analytics-design.md`. Records the decisions taken for the Mixpanel implementation: full locale-aware consent port, `AnalyticsClient` protocol (overriding the earlier "no abstraction" decision), `UserDefaults` rather than iCloud KV for identity, and the consent-sheet trigger on first `checklist_viewed`. Token/secrets mechanism, privacy manifest, and gitleaks rule built and verified end to end; both Mixpanel projects provisioned and their five boards built via MCP. Client, consent, and SDK pending. |
