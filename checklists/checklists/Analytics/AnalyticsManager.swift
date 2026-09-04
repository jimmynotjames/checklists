//
//  AnalyticsManager.swift
//  checklists
//
//  Created by Jimmy Ho on 9/4/19.
//

// MARK: - Status: analytics are STUBBED. There is no backend.

//
// This app was instrumented with Flurry Analytics 11.2.0 (vendored static library) from 2019
// until Flurry was removed. Flurry reached end of life; Mixpanel is the intended replacement but
// is not wired up yet. Every function below keeps its exact signature and call sites, but the
// events go nowhere: `logEvent` prints in DEBUG and does nothing in Release.
//
// The full tracking plan — every event, every property, what each one recorded under Flurry, and
// the decisions still open — lives in `core-docs/analytics-design.md`. Read that before
// implementing Mixpanel. The sibling `budgets1` repo has a complete Mixpanel implementation
// (`simple-recurring-budgets/Logging/`, `docs/analytics-spec.md`) that this file's naming
// conventions were deliberately aligned to.
//
// **Capabilities lost with Flurry, which Mixpanel will NOT restore for free:**
//
// - **Crash reporting.** Flurry was started with `withCrashReporting(true)`, so crashes were
//   reported automatically. Mixpanel has no crash reporting. If crash visibility matters, that is
//   a separate SDK decision (Sentry, Firebase Crashlytics, or Xcode Organizer alone).
// - **Automatic session tracking.** Flurry's `startSession` began a session and derived
//   session/DAU metrics server-side with no explicit event. Mixpanel does not do this — sessions
//   are computed from an event stream, so an explicit `app_opened` event must be sent on every
//   foreground. `AnalyticsEvent.appOpened` exists for that and is fired from `appLaunched()`.
// - **Log-level control** (`withLogLevel`) and the vendored GDPR/CCPA consent objects
//   (`FlurryConsent`, `FlurryCCPA`) — the latter were never actually used by this app.

import Foundation
import UIKit

enum AnalyticsManager {
  // MARK: - Session

  /// Called once from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
  ///
  /// **Under Flurry** this built a `FlurrySessionBuilder` (crash reporting on, log level
  /// `CriticalOnly`, app version = `SettingsManager.versionBuildString`) and called
  /// `Flurry.startSession(_:with:)` with a hardcoded API key. It emitted no event of its own —
  /// Flurry derived sessions server-side from the session start.
  ///
  /// **For Mixpanel**, four things belong here, in this order. Steps 2 and 4 are already wired up
  /// below as no-ops, so only 1 and 3 need inserting — do not re-order them around the existing
  /// calls, and note that `registerSuperProperties()` must run *before* the first `logEvent` so
  /// `app_opened` carries the super properties too:
  ///   1. `Mixpanel.initialize(token: <token>, trackAutomaticEvents: false)`. The token must come
  ///      from an xcconfig-injected Info.plist key, never a literal — the Flurry key was hardcoded
  ///      on this line for six years (see issue #115).
  ///   2. `registerSuperProperties()` — already called below.
  ///   3. `identify(distinctId:)` with a UUID generated once and persisted (`budgets1` keeps its
  ///      copy in `NSUbiquitousKeyValueStore` so one person unifies across devices).
  ///   4. `logEvent(AnalyticsEvent.appOpened)` — already called below. Mixpanel does not track
  ///      sessions on its own.
  ///
  /// Note this must also fire on foreground returns, not just cold launch, which the current
  /// single `didFinishLaunching` call site does not do.
  static func appLaunched() {
    registerSuperProperties()
    logEvent(AnalyticsEvent.appOpened)
  }

  /// Registers the properties that should be attached to *every* event rather than passed per
  /// call. No-op until Mixpanel is wired up; `Mixpanel.registerSuperProperties(_:)` is the target.
  ///
  /// Called from `appLaunched()` before the first event, so filling in this body is all that is
  /// needed — there is no call site left to remember to add.
  ///
  /// **Under Flurry** only the app version was set this way, via
  /// `withAppVersion(SettingsManager.versionBuildString)`. The rest were either unavailable or
  /// were redundantly attached to individual events.
  ///
  /// The intended set, matching `budgets1`:
  ///   - `app_version` / `app_build` — from `CFBundleShortVersionString` / `CFBundleVersion`.
  ///     `SettingsManager.versionBuildString` combines both into one display string; send them
  ///     separately so they can be filtered on.
  ///   - `device_class` — `phone` / `pad`. This replaces the per-event `ui_idiom` property that
  ///     `orientation_changed` used to carry: it is constant for an install, so it does not belong
  ///     on individual events.
  ///   - `locale` / `region` — `Locale.current.identifier`, and for the region
  ///     **`Locale.current.regionCode`** on this deployment target. `Locale.current.region` (what
  ///     `budgets1` uses) is iOS 16+ and will not compile against iOS 13.2 — switch to it when the
  ///     deployment target is raised. See issue #119.
  static func registerSuperProperties() {
    // No-op: no analytics backend. See core-docs/analytics-design.md.
  }

  // MARK: - Utilities

  /// The single sink every event flows through. This is where the Mixpanel cutover happens.
  ///
  /// **Under Flurry** this called `Flurry.logEvent(_:withParameters:)`, wrapped in
  /// `#if DEBUG / #else` so debug builds sent nothing at all. That silence made local
  /// instrumentation work impossible to verify, so the stub prints instead.
  ///
  /// The parameter type is `[String: Any]` rather than Flurry's `[AnyHashable: Any]` precisely so
  /// this swap stays mechanical: Mixpanel's `track` takes `[String: MixpanelType]`, so the keys
  /// already line up and only the values need bridging:
  ///
  ///     Mixpanel.mainInstance().track(
  ///       event: eventName,
  ///       properties: params?.compactMapValues { $0 as? MixpanelType }
  ///     )
  ///
  /// Be aware `compactMapValues` **silently drops** any value that is not a `MixpanelType`, so a
  /// property of the wrong type becomes a missing property in production rather than a build
  /// error. Everything currently passed is a `String` or an `Int`, both of which conform.
  static func logEvent(_ eventName: String, withParameters params: [String: Any]? = nil) {
    #if DEBUG
      if let params, !params.isEmpty {
        print("[analytics] \(eventName) \(params)")
      } else {
        print("[analytics] \(eventName)")
      }
    #endif
  }

  /// Truncates a user-supplied or error string before it is sent as a property value.
  ///
  /// 127 characters was chosen against Flurry's 255-character parameter limit, halved in case the
  /// limit was counted in UTF-8 bytes rather than characters. Mixpanel's own limit is also 255
  /// characters, so the value carries over unchanged.
  static func truncatedString(_ s: String) -> String {
    String(s.prefix(127))
  }

  // MARK: - Page View Analytics

  static func logChecklistsViewed(numChecklists: Int) {
    logEvent(AnalyticsEvent.checklistsViewed, withParameters: [AnalyticsProperty.checklistsCount: numChecklists])
  }

  static func logChecklistViewed(
    checklistName: String,
    checklistNotesLength: Int,
    numItems: Int,
    numItemsWithNotes: Int
  ) {
    let params: [String: Any] = [
      // ACCEPTED RISK: this is raw user content. Deliberately retained — see core-docs/analytics-design.md.
      AnalyticsProperty.checklistName: checklistName,
      AnalyticsProperty.notesLength: checklistNotesLength,
      AnalyticsProperty.itemsCount: numItems,
      AnalyticsProperty.itemsWithNotesCount: numItemsWithNotes,
    ]
    logEvent(AnalyticsEvent.checklistViewed, withParameters: params)
  }

  static func logSettingsViewed() {
    logEvent(AnalyticsEvent.settingsViewed)
  }

  static func logMainMenuViewed() {
    logEvent(AnalyticsEvent.mainMenuViewed)
  }

  // MARK: - Other Navigation Analytics

  static func logRateInAppStore() {
    logEvent(AnalyticsEvent.rateAppTapped)
  }

  static func logSendFeedback() {
    logEvent(AnalyticsEvent.feedbackTapped)
  }

  static func logViewPrivacyPolicy() {
    logEvent(AnalyticsEvent.privacyPolicyTapped)
  }

  // MARK: - General User Actions

  static func logNewChecklist() {
    logEvent(AnalyticsEvent.checklistCreated)
  }

  static func logResetChecklist() {
    logEvent(AnalyticsEvent.checklistReset)
  }

  // MARK: - Error Logging

  /// The store could not be opened at all. Renamed off "Realm" along with the persistence-layer
  /// swap; the underlying event names were already storage-agnostic and are unchanged, so the
  /// event history stays continuous across the migration.
  static func logPersistenceFailure(errorMessage: String) {
    logEvent(AnalyticsEvent.persistenceFatalError, withParameters: [AnalyticsProperty.error: truncatedString(errorMessage)])
  }

  static func logPersistenceWriteFailure(errorMessage: String) {
    logEvent(AnalyticsEvent.persistenceWriteFailed, withParameters: [AnalyticsProperty.error: truncatedString(errorMessage)])
  }

  // MARK: - Device info analytics

  /// Overall ratio of iPad versus iPhone can be found in App Store Connect Analytics, so leaving that out here.
  static func logDeviceOrientationChange() {
    let orientation = UIDevice.current.orientation
    guard orientation.isPortrait || orientation.isLandscape else { return } // When it's laid flat, it will also fire, and we're filtering it out here.
    // To be technical, our app doesn't support upside down portrait, but this will log it. Not worth extra code to fix.
    let orientationString = orientation.isPortrait ? "portrait" : "landscape"
    // The `ui_idiom` property this event used to carry became the `device_class` super property —
    // it never varied within an install. See `registerSuperProperties()`.
    logEvent(AnalyticsEvent.orientationChanged, withParameters: [AnalyticsProperty.orientation: orientationString])
  }
}

// MARK: - Canonical event names

/// Event-name constants. All names are flat `snake_case`, `noun_pastTenseVerb`, matching the
/// convention in `budgets1`'s `AnalyticsEvent`. Use these at every call site — never a string
/// literal — so a typo is a compile error.
///
/// These were renamed when Flurry was removed. Nothing depended on the old names: the Flurry data
/// is not migrating anywhere, so there was no continuity to preserve. The old Flurry name is noted
/// on each constant for anyone reading historical Flurry exports. `core-docs/analytics-design.md` has the full
/// mapping table.
enum AnalyticsEvent {
  // MARK: Session

  /// App brought to the foreground. **New** — Flurry had no equivalent event because
  /// `startSession` gave it sessions automatically. Mixpanel needs this explicitly.
  static let appOpened = "app_opened"

  // MARK: Page views

  /// Checklists list shown. Flurry: `checklists_viewed` (unchanged).
  static let checklistsViewed = "checklists_viewed"
  /// A single checklist opened. Flurry: `checklist_viewed` (unchanged).
  static let checklistViewed = "checklist_viewed"
  /// Settings screen shown. Flurry: `settings_viewed` (unchanged).
  static let settingsViewed = "settings_viewed"
  /// Main menu shown. Flurry: `main_menu_viewed` (unchanged).
  static let mainMenuViewed = "main_menu_viewed"

  // MARK: Navigation out of the app

  /// "Rate in App Store" tapped. Flurry: `rate_in_app_store`.
  static let rateAppTapped = "rate_app_tapped"
  /// "Send feedback" tapped. Flurry: `send_feedback`.
  static let feedbackTapped = "feedback_tapped"
  /// Privacy policy opened. Flurry: `view_privacy_policy`.
  static let privacyPolicyTapped = "privacy_policy_tapped"

  // MARK: User actions

  /// A new checklist was created. Flurry: `create_new_checklist`.
  static let checklistCreated = "checklist_created"
  /// A checklist's items were all unchecked. Flurry: `reset_checklist`.
  static let checklistReset = "checklist_reset"

  // MARK: Errors

  /// Realm could not be opened — the app calls `fatalError` right after this.
  /// Flurry: `realm/fatal_error`. Renamed off "realm" so the event survives a future
  /// persistence-layer swap; `budgets1` uses the same `persistence_*` prefix.
  static let persistenceFatalError = "persistence_fatal_error"
  /// A Realm write transaction threw. Flurry: `realm/write_error`.
  static let persistenceWriteFailed = "persistence_write_failed"

  // MARK: Device

  /// Device rotated between portrait and landscape. Flurry: `orientation_changed` (unchanged),
  /// but it no longer carries `ui_idiom` — that became the `device_class` super property.
  static let orientationChanged = "orientation_changed"
}

// MARK: - Canonical property keys

/// Property-key constants, all `snake_case`. Matches `budgets1`'s `AnalyticsProperty`.
enum AnalyticsProperty {
  // MARK: checklists_viewed

  /// Number of checklists in the list. Flurry: `num_checklists`.
  static let checklistsCount = "checklists_count"

  // MARK: checklist_viewed

  /// **Raw checklist name — user content.** Flurry: `name`.
  ///
  /// Retained as an accepted risk rather than dropped or bucketed, mirroring the way `budgets1`
  /// allow-lists `budget_name`. It is the one free-text property this app sends. Documented in
  /// `core-docs/analytics-design.md`; revisit it alongside the consent work.
  static let checklistName = "checklist_name"
  /// Character count of the checklist's notes field. Flurry: `notesLength` — the one camelCase
  /// key in the old catalog.
  static let notesLength = "notes_length"
  /// Number of items in the checklist. Flurry: `num_items`.
  static let itemsCount = "items_count"
  /// Number of items that have notes. Flurry: `num_items_with_notes`.
  static let itemsWithNotesCount = "items_with_notes_count"

  // MARK: Errors and failures

  /// Error message, truncated by `truncatedString`. Flurry: `error` (unchanged).
  static let error = "error"

  // MARK: orientation_changed

  /// `portrait` or `landscape`. Flurry: `orientation` (unchanged).
  static let orientation = "orientation"

  // MARK: Super properties (not yet sent — see `registerSuperProperties()`)

  /// `CFBundleShortVersionString`. Flurry received this via `withAppVersion`, combined with the
  /// build number into a single string.
  static let appVersion = "app_version"
  /// `CFBundleVersion`.
  static let appBuild = "app_build"
  /// `phone` / `pad`. Replaces the old per-event `ui_idiom` property.
  static let deviceClass = "device_class"
  /// `Locale.current.identifier`.
  static let locale = "locale"
  /// `Locale.current.regionCode` on iOS 13.2; `Locale.current.region?.identifier` once the
  /// deployment target reaches iOS 16+. See issue #119.
  static let region = "region"
}
