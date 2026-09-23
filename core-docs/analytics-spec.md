# Analytics Spec

What this app measures, what it refuses to measure, and how it is wired. Where this document and
the code disagree, one of them is a bug — say which in the PR.

Debug builds send to the Dev project. **No App Store build carries the SDK yet**; see
§Published disclosures.

## Scope

- Mixpanel (`mixpanel-swift`, SPM, `upToNextMajorVersion` from 6.5.0), Growth plan.
- Projects `reChecklist App - Prod` (4062256) and `reChecklist App - Dev` (4062257), picked by
  `#if DEBUG`.
- Automatic events **off** (`trackAutomaticEvents: false`). No crash reporting (Xcode Organizer
  only). No IDFA, no ATT prompt.
- Sessions are derived server-side from `app_opened`.

## Constraints

A change that breaks one of these is a spec change, not an implementation detail.

1. **No PII beyond §Free-text exception.** The default is deny.
2. **Consent is locale-aware**: strict opt-in where required, auto opt-in elsewhere (§Consent).
3. **An opted-out install never opens a Mixpanel connection.** SDK init is lazy, behind the consent
   gate — not an SDK opt-out after init.
4. **`OSLog` is never forwarded to analytics**, and analytics never replaces an `OSLog` call.
5. **No string literals at call sites.** Names are constants in `Analytics/AnalyticsNames.swift`.
6. **The project token is never a source literal** (§Build hygiene).
7. **No engagement-pressure events.** The rating-prompt events record when the app's fixed bar was
   met and when it asked — not how to move anyone toward it.
8. **Counts on events are raw; cohort signals on profiles are bucketed.**

## Product questions

A dashboard is justified by a question here. The IDs are stable; board names cite them.

| # | Question | Served by |
| --- | --- | --- |
| 3.1 | How many people use the app, how often, do they return? | `app_opened`, retention |
| 3.2 | What do people make checklists *for*? | `checklist_name` |
| 3.3 | How big do checklists get, and how many per person? | `checklists_count`, `items_count`, `notes_length` |
| 3.4 | Is the notes feature used? | `items_with_notes_count`, `notes_length` |
| 3.5 | Reuse (reset), template (duplicate, copy items), or disposable (create, delete)? | the five checklist action events |
| 3.6 | How often does the store fail to open, and how often is that unrecoverable? | `startup_failed` / `startup_store_reset` at `startup_stage = store_open` |
| 3.7 | Does anyone rotate the device? | `orientation_changed` |
| 3.8 | What share opt out, by jurisdiction? | `analytics_consent_changed`, `consent_jurisdiction` |
| 3.9 | When do people reach the review-prompt bar, and how soon does the app ask? | `rating_prompt_eligible` → `rating_prompt_requested` |
| 3.10 | How often does an upgrader's old data end up out of reach? | `startup_failed` at `legacy_import`, `legacy_import_abandoned` |
| 3.11 | Is sync working, and when it isn't, why? | `icloud_status_checked`, `cloudkit_container_fell_back`, `cloudkit_sync_failed` |

3.9 stops at the request: `requestReview` reports neither whether the dialog showed nor what was
chosen, and no custom pre-prompt manufactures that signal. The bar is three constants on
`RatingPromptCoordinator`.

3.7 exists to decide whether `orientation_changed` and `ChecklistsApp`'s
`beginGeneratingDeviceOrientationNotifications()` call are worth keeping.

## Privacy

### Allow-list

**The default is deny.** A field is sent only if it is listed here; adding one is a spec change
with its rationale recorded here. The app code sends exactly:

- **Event names** in §Event catalog.
- **Event properties:** `checklists_count`, `items_count`, `items_with_notes_count`, `notes_length`
  (integers, never content); `checklist_name` (§Free-text exception); `source`, `destination`,
  `orientation`, `error_operation`, `startup_stage`, `container_backing`, `icloud_account`,
  `sync_operation` (app-owned enumerations); `error_domain`, `error_code` (an `NSError`'s domain and
  code, never its `userInfo`); `new_value`, `old_value` (booleans); `time_since_first_eligible_bucket`
  (a bucket, not a timestamp).
- **Super properties:** `app_version`, `app_build`, `device_class`, `locale`, `region`,
  `consent_jurisdiction`. `locale` and `region` are device *settings*, not a position.
- **People properties:** `first_seen_at`, `last_app_open_at`, `analytics_opt_in_at`,
  `checklists_count_bucket`, `rating_prompt_first_eligible_at`, `rating_prompt_last_requested_at`.
- **`distinct_id`**, a random app-generated UUID (§Identity).

The SDK also attaches its own device, network, app-version and library properties to events and
people records (`AutomaticProperties.swift` in `mixpanel-swift`: OS, model, screen size, radio,
carrier, wifi), plus identity fields such as `$device_id`, `$user_id` and a session-metadata block.
`trackAutomaticEvents: false` does not remove them. `$device_id` is an SDK-generated random UUID,
not the IDFV (`useUniqueDistinctId` stays off). Mixpanel also sees the request IP. Recheck this
paragraph when bumping the SDK.

### Deny-list

| Never sent | Instead / why |
| --- | --- |
| **Item names, item notes, checklist notes** | `items_count`, `items_with_notes_count`, `notes_length` |
| Apple identifiers (IDFA, IDFV, device name) | No tracking |
| IP-derived geolocation (`$city`, `$region`, `mp_country_code`) | `useIPAddressForGeoLocation = false`; the region *setting* is the location signal, so no location type is declared in `PrivacyInfo.xcprivacy` |
| iCloud account ids, CloudKit record names | Identity is the app UUID only |
| An `NSError`'s `userInfo`, `description`, `localizedDescription` | Unbounded; can serialise user content |
| `OSLog` message text | §OSLog boundary |
| Legacy Realm import contents | Only success or failure is reported |

### Free-text exception

`checklist_viewed` sends the checklist's name, truncated by `AnalyticsText`. Nothing else answers
3.2, the most valuable question this app has.

- It is the **only** free-text property; another would be a new decision, not this precedent.
- It sits **behind the consent gate**, which is why the first-run sheet fires right before the
  first `checklist_viewed`.
- It is declared as `NSPrivacyCollectedDataTypeOtherUserContent`.
- It is the first thing to cut if it proves uninteresting or the disclosure burden grows.

### Enforcement

No lint can tell a name from a count. Enforcement is the pointer on the `AnalyticsClient`
protocol, constants-only names, the **Analytics** item in `.github/pull_request_template.md`, and
the cross-cutting audit in `/create-pr` and `/create-pr-for-issue`.

## Identity

`distinct_id` is a **UUIDv4 the app generates once** and persists — not the IDFV or any Apple
identifier. `reset()` clears the SDK's copy, not the persisted one, so a re-opt-in rejoins the same
profile.

It lives in `UserDefaults.standard`, not `NSUbiquitousKeyValueStore`: `checklists.entitlements`
lacks `com.apple.developer.ubiquity-kvstore-identifier`, so iCloud KVS would not sync. So consent
and identity are **per device**, which `TARGETED_DEVICE_FAMILY = 1` makes nearly per person. The
`KeyValueStore` seam makes a later move a store swap plus a read-through migration.

`RatingPromptState` uses the same seam and store but is **not** analytics state and **not**
consent-gated: an opted-out install earns its prompt on the same schedule; only the two events are
dropped.

Test launches get a fresh in-memory store instead; the rules are on `AnalyticsSettings.makeStore`.

**`StoreReset.startOverFresh()` keeps the analytics keys.** A data reset is not a consent
withdrawal. `StoreResetTests` pins it.

## Consent

### Settings toggle

Every install, in every jurisdiction, can turn analytics off from Settings at any time.

### Strict-opt-in jurisdictions

In strict-opt-in regions analytics are **off** until the person accepts; elsewhere they default
**on**. The list is canonical in `ConsentJurisdiction.strictOptInRegions`. A **nil** region
resolves to `.required`; any code not on the list resolves to `.autoOptin`.

**The resolved default is never written.** "A choice was made" is exactly
`store.object(forKey:) != nil`, and that gates the sheet.

**Trigger: the first `checklist_viewed` on a pushed checklist**, in a strict region, with no choice
yet. Sample checklists are seeded, so a person may never create one, but always opens one — and
that is when `checklist_name` would first be sent. The new-checklist route is excluded: there the
checklist screen *is* the presented sheet.

**No retroactive replay.** Events before consent are dropped, not buffered.

### Toggle-off behaviour

The order is the contract, held in `AnalyticsConsentController`:

1. Track `analytics_consent_changed` with `new_value: false` **while still opted in** — the only
   record of the opt-out.
2. `reset()` — clears the Mixpanel instance and its queue.
3. Store `false`.

Toggle-on and the sheet's accept reverse it: store `true` first, so the lazy initializer sees
opt-in, then track, then stamp `analytics_opt_in_at`. Declining the sheet, swipe included, stores an
**explicit** `false` and sends nothing.

## Architecture

### Client selection

- Running tests (`LaunchModeContainerFactory.isRunningTests`: `-UITests1` **or** `IS_TESTING`) →
  `ConsoleAnalyticsClient`. XCUITest passes only the launch argument.
- Active token not configured (fresh clone) → `ConsoleAnalyticsClient`.
- Otherwise → `MixpanelAnalyticsClient`.

`ChecklistsApp.shouldUseConsoleClient(isRunningTests:isTokenConfigured:)` is this table.
`ConsoleAnalyticsClient` prints in DEBUG, is silent in Release, and is the environment default.

### Launch and consent ordering

**Cold launch:** build the client → wrap it in `ConsentGatedAnalyticsClient` → install it in
`AppAnalytics` → build the startup model → inject it into the environment for every phase → fire
`app_opened` once the scene is active.

**The gate is a decorator** and the only path to the base client. It drops every call except
`reset()` while opted out; `reset()` always passes, so it can clear state whatever the flag says.
It must therefore never initialize the SDK itself (`MixpanelClientGateTests`).

**SDK init is lazy.** `Mixpanel.initialize` runs only in `ensureInitialized()`, reached from
`track` and `identify`, so an opted-out install never builds an instance. `reset()` discards it; a
later opt-in re-runs init, which re-registers super properties and re-identifies.

### Non-SwiftUI callers

`ChecklistViewController` gets the client as a stored property from `ChecklistScreen`, defaulting
to the console client.

The persistence layer (`ProductionContainerFactory`, `AppStartupCoordinator`,
`LegacyRealmImporter`, `ModelContext.saveChanges`) runs inside `AppStartupModel.init()`, with no
environment. Each takes a parameter defaulting to `AppAnalytics.shared`.

> **Install before startup.** `AppStartupModel.init()` runs startup synchronously, and stored
> properties initialize before `init()`'s body. `ChecklistsApp` must install `AppAnalytics` first
> and build the model in `init()`, or the persistence events silently go to the console client.

`AnalyticsEvent`, `AnalyticsProperty` and `AnalyticsText` are `nonisolated` types, because
nonisolated `@Model` extensions (such as `checklist_viewed`'s properties) use them.

**Error events are consent-gated too**, so strict regions drop them on the launch that matters
most. That is correct; `OSLog` is the complete record. Do not exempt them.

## Event catalog

Flat `snake_case`, `noun_pastTenseVerb`.

| Event | Fires when | Properties |
| --- | --- | --- |
| `app_opened` | Cold launch, **and** every return from background | — |
| `checklists_viewed` | The checklists list appears | `checklists_count` |
| `checklist_viewed` | A checklist is opened | `checklist_name`, `notes_length`, `items_count`, `items_with_notes_count` |
| `settings_viewed` | Settings appears | — |
| `main_menu_viewed` | The main menu appears | — |
| `checklist_created` | A checklist is created | — |
| `checklist_duplicated` | Copied, from the list's swipe or the checklist menu | `source` |
| `checklist_items_copied` | Ticked items copied into another checklist, from the checklist menu | `destination` |
| `checklist_reset` | All items unchecked | — |
| `checklist_deleted` | Deleted, from the list's swipe or the checklist menu | — |
| `rate_app_tapped` | "Rate in App Store" tapped | — |
| `feedback_tapped` | "Send feedback" tapped, main menu **or** failure screen | — |
| `privacy_policy_tapped` | The privacy policy is opened | — |
| `orientation_changed` | Portrait ↔ landscape | `orientation` |
| `persistence_fatal_error` | The store cannot be opened | `error_domain`, `error_code` |
| `persistence_write_failed` | A SwiftData save throws | `error_domain`, `error_code`, `error_operation` |
| `startup_failed` | The failure screen is shown | `error_domain`, `error_code`, `startup_stage` |
| `startup_store_reset` | "Start over fresh" chosen (offered only at `store_open`) | — |
| `legacy_import_abandoned` | The Realm import failed `LegacyRealmImporter.maximumAttempts` times | `error_domain`, `error_code` |
| `icloud_status_checked` | Once per cold launch, the first time the account status leaves `.checking` | `container_backing`, `icloud_account` |
| `cloudkit_container_fell_back` | The CloudKit store failed to open and launch used the local one | `error_domain`, `error_code` |
| `cloudkit_sync_failed` | A sync event fails; once per (operation, domain, code) per launch | `sync_operation`, `error_domain`, `error_code` |
| `analytics_consent_changed` | The toggle or first-run sheet changes the setting | `new_value`, `old_value` |
| `rating_prompt_eligible` | Every review-prompt threshold first met; **once per install** | — |
| `rating_prompt_requested` | `requestReview` called; once per app version | `time_since_first_eligible_bucket` |

The rating-prompt events fire from `RatingPromptCoordinator`; its doc comment has the mechanics.

## Property catalog

### Per-event properties

| Property | Type | Values / notes |
| --- | --- | --- |
| `checklists_count` | Int | Raw |
| `checklist_name` | String | **User content**, `AnalyticsText.truncated` |
| `notes_length` | Int | Characters in the checklist's notes; 0 when absent |
| `items_count` | Int | |
| `items_with_notes_count` | Int | Items with non-nil, non-empty notes |
| `source` | String | `menu` / `swipe` |
| `destination` | String | `new` / `existing` |
| `error_domain` | String | `NSError.domain` |
| `error_code` | Int | `NSError.code` |
| `error_operation` | String | `PersistenceOperation.rawValue`: `checklistEdit`, `itemEdit`, `itemUpdate`, `reorder`, `delete`, `legacyImport`, `sampleSeed`, `dedupe` |
| `startup_stage` | String | `ContainerCreationFailure.Stage.rawValue`: `store_open`, `legacy_import`, `first_launch_seed` |
| `container_backing` | String | `ContainerBacking.rawValue`: `cloudkit`, `local_fallback` |
| `icloud_account` | String | `SyncStatus.AccountStatus.rawValue`: `available`, `no_account`, `restricted`, `temporarily_unavailable`, `could_not_determine` (`.checking` is never sent) |
| `sync_operation` | String | `SyncOperation.rawValue`: `setup`, `import`, `export` |
| `orientation` | String | `portrait` / `landscape`; face-up/down are dropped |
| `new_value` / `old_value` | Bool | |
| `time_since_first_eligible_bucket` | String | `<1d` / `<7d` / `<30d` / `30d+` |

`error_operation` values are Swift case names, so renaming a case changes the dashboards.
`AnalyticsNamesTests` pins the value sets of `source`, `destination`, `error_operation`,
`startup_stage`, `container_backing`, `icloud_account`, and `sync_operation`. 3.6 must be filtered by
`startup_stage`, since only `store_open` offers the reset.

Counts are raw: Mixpanel handles numbers natively, and bucketing for privacy would be incoherent
while the name is sent.

### Super properties

Registered on lazy SDK init, so they ride on every event and re-register after reset → opt-in.

| Super property | Source |
| --- | --- |
| `app_version` | `CFBundleShortVersionString` |
| `app_build` | `CFBundleVersion` |
| `device_class` | `userInterfaceIdiom` → `phone` / `pad` / `mac` (other → `phone`) |
| `locale` | `Locale.current.identifier` |
| `region` | `Locale.current.region?.identifier` — the region *setting* |
| `consent_jurisdiction` | `required` / `auto_optin` |

Never send `SettingsManager.versionBuildString` (it merges both and appends `- DEBUG`).
`consent_jurisdiction` tells a consent-driven gap from a real drop in usage.

### People properties

| People property | Set when |
| --- | --- |
| `first_seen_at` | `setOnce` on SDK init |
| `last_app_open_at` | SDK init and every `app_opened` |
| `analytics_opt_in_at` | The opt-in transition |
| `checklists_count_bucket` | `0` / `1` / `2-3` / `4-7` / `8+`, on `checklists_viewed` (`@Query` lags `checklist_created`) |
| `rating_prompt_first_eligible_at` | With `rating_prompt_eligible` |
| `rating_prompt_last_requested_at` | Every `rating_prompt_requested` |

`analytics_opt_in_at` is absent on an auto-opt-in install that never touches the toggle, and
`rating_prompt_first_eligible_at` for anyone who hit the bar while opted out. Pair them with
`consent_jurisdiction`; neither covers every install.

## Build hygiene

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

- **Sentinels** live in `config/Secrets.xcconfig`, `AppConfig.Placeholder` and
  `scripts/verify_release_secrets.sh`, which must agree. `AppConfigSentinelTests` guards the Swift
  half.
- **Validity is shape**: `MixpanelTokenSource.isValidToken` and the ship guard both require 32
  lowercase hex characters, rejecting the template's unfilled placeholder too.
- **Only the active token counts**: `isConfigured` checks the active one, the ship guard the prod
  one.
- **A fresh clone works**: no local file → empty token → console client.
- **The ship guard**, `verify_release_secrets.sh`, refuses a Release archive with a placeholder
  prod token or no local file. It runs from `make verify-secrets`, the release-candidate lane in
  `fastlane/lib/release_build.rb`, and an archive-only Xcode phase
  (`runOnlyForDeploymentPostprocessing`) that lists the three files as `inputPaths` for the script
  sandbox, via `$(SRCROOT)/../` (`SRCROOT` is `checklists/`). There it checks the resolved
  `$MIXPANEL_PROD_TOKEN`, not the file, so a dropped `baseConfigurationReference` cannot pass. It
  is not in `make gate` or lefthook: a fresh clone has no secrets file.
- **Gitleaks**: `.gitleaks.toml` adds a Mixpanel-token rule with **no allowlist** — exempting
  `config/Secrets.xcconfig` would blind it where a paste is likeliest. The `.gitignore` entry is the
  real defence.
- **Both tokens ship in Info.plist.** Project tokens are client-side credentials, so the extra
  exposure is junk events into the other project. Revisit if that happens.
- **Export compliance**: `ITSAppUsesNonExemptEncryption = false` holds only while all encryption is
  OS-provided. A Realm `encryptionKey` or custom crypto means `true` plus
  `ITSEncryptionExportComplianceCode`.

**Privacy manifest.** `PrivacyInfo.xcprivacy`: `NSPrivacyTracking = false`, no tracking domains,
`UserDefaults` reason `CA92.1`, and these collected types — linked, purpose Analytics, not tracking:

| Type | Covers |
| --- | --- |
| Product Interaction | Screen views, counts, action events |
| Other User Content | `checklist_name` |
| Device ID | `distinct_id` — app-generated, but a per-install id sent to a third party, and why the rest is *linked* |
| Other Diagnostic Data | The `error_*` properties; `container_backing`, `icloud_account`, `sync_operation` are the same declared type, no manifest change needed |

## OSLog boundary

`Logging/AppLoggers.swift` is the **diagnostics** channel, analytics the **product** channel. A
developer-facing failure goes to `OSLog`; aggregate behaviour to analytics; a failure that is both
gets **sibling calls**, neither deriving its arguments from the other.

`OSLog` is synchronous, so it survives a following `fatalError`, and it is **not consent-gated**,
so it is the complete record. Never route it into Mixpanel, and never delete an `OSLog` call
because analytics covers the same failure.

## Dashboards

Boards live in Prod (Release and TestFlight builds) and are mirrored in Dev (Debug), which is the
pre-release smoke test. **Mixpanel is the source of truth**; the MCP server can edit
boards directly.

Name boards for the **behaviour** shown, citing one question ID from §Product questions. No ticket
IDs, tooling notes or filter mechanics in names; one short framing text card per board. `notes_length`
is not charted (`items_with_notes_count` answers 3.4 better). **Never** query a deny-listed field.

## Published disclosures

- **Privacy policy**: <https://jimmynotjames.github.io/checklists/privacy.html> (`privacy.html` on
  `gh-pages`), naming Mixpanel as processor. The URL is in `SettingsView.swift` and
  `fastlane/metadata/en-US/privacy_url.txt`.
- **Nutrition label**: the manifest's types, Linked, Analytics, not tracking.

**Do not push the App Store listing yet.** `privacy_url.txt` must not reach App Store Connect before
the first SDK build is submitted; the listing's older privacy page is correct while no shipped
build collects anything. Run `push_metadata` in the release that ships the SDK.

Deliberate — do not "fix":

1. **The policy is a generic TermsFeed template**, not an event inventory; a rewrite would draw on
   §Privacy and §Consent. Departures from it remove collection, sale or sharing this app does not do.
2. **It names the Settings toggle** as the opt-out; the template's `mixpanel.com/optout` does
   nothing for a native SDK.
3. **CCPA A and F are "Collected: Yes"**, the rest "No": `distinct_id` is an identifier, and
   Mixpanel sees the IP regardless of `useIPAddressForGeoLocation`.

Apple validates only the manifest's schema. The label is editable without a build; fix it when it
drifts and converge the manifest next release.

## Keeping current

When the analytics surface changes — an event, a property, a categorical value, a super or people
property, a jurisdiction — **update this file in the same change**. The catalogs are what the app
should emit; `AnalyticsNames.swift` is what it does emit.

The `checklistsTests/` suites pin these contracts. One case is deliberately untested: that an
opted-in `track` initializes the SDK once, because `Mixpanel.initialize` contacts
`api.mixpanel.com` even with a fake token.
