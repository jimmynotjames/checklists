//
//  AnalyticsNames.swift
//  checklists
//

// MARK: - Canonical event names

/// Event-name constants. All names are flat `snake_case`, `noun_pastTenseVerb`. Use these at every
/// call site — never a string literal — so a typo is a compile error rather than a second event
/// that looks like the first in a dashboard listing.
///
/// This enum and `AnalyticsProperty` below are the code-side mirror of the catalogs in
/// core-docs/analytics-spec.md §8 and §9. **Change them together**, in the same PR.
///
/// The enum is `nonisolated` because these are plain compile-time strings with no state and no
/// business being actor-isolated. The target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so
/// without it every name would inherit MainActor isolation and could only be read from the main
/// actor — which silently limits where events can be assembled. `Checklist`'s
/// `analyticsViewedProperties` is the case that hits it today, since `@Model` types are
/// nonisolated, but the annotation is about the constants, not about SwiftData.
nonisolated enum AnalyticsEvent {
  // MARK: Session

  /// App brought to the foreground — a cold launch or a return from background.
  ///
  /// Mixpanel derives sessions server-side from this event, so it has to be sent explicitly on
  /// every foreground rather than only at launch. `AppOpenTracker` decides which scene-phase
  /// transitions qualify.
  static let appOpened = "app_opened"

  // MARK: Page views

  /// Checklists list shown. Carries `checklists_count`.
  static let checklistsViewed = "checklists_viewed"
  /// A single checklist opened. Carries the checklist's name and its size — see
  /// `Checklist.analyticsViewedProperties`.
  static let checklistViewed = "checklist_viewed"
  /// Settings screen shown.
  static let settingsViewed = "settings_viewed"
  /// Main menu shown.
  static let mainMenuViewed = "main_menu_viewed"

  // MARK: Navigation out of the app

  /// "Rate in App Store" tapped.
  static let rateAppTapped = "rate_app_tapped"
  /// "Send feedback" tapped, from either the main menu or the startup-failure screen.
  static let feedbackTapped = "feedback_tapped"
  /// Privacy policy opened.
  static let privacyPolicyTapped = "privacy_policy_tapped"

  // MARK: User actions

  /// A new checklist was created.
  static let checklistCreated = "checklist_created"
  /// Every item in a checklist was unchecked at once.
  ///
  /// Read against `checklist_created`: resetting says people reuse a checklist, creating says they
  /// treat them as disposable.
  static let checklistReset = "checklist_reset"

  // MARK: Errors

  /// The persistent store could not be opened at all.
  ///
  /// Named for persistence rather than for any one storage engine, so it survives a swap of the
  /// layer underneath. Treat its count as a floor: the app stops immediately afterwards, so the
  /// event often never reaches the network. `AppLog.cloudKit` is the complete record.
  static let persistenceFatalError = "persistence_fatal_error"
  /// A save threw.
  static let persistenceWriteFailed = "persistence_write_failed"
  /// Launch could not produce a usable store, so the retry screen was shown instead of the app.
  ///
  /// Covers all three causes — the container would not open, the one-time legacy import did not
  /// complete, or first-launch seeding would not save — because the user-facing outcome is the
  /// same for all three. No data has been lost when this fires.
  static let startupFailed = "startup_failed"
  /// The user gave up on that screen and wiped this device's stores to get a working app back.
  ///
  /// Paired with `startup_failed`, the ratio says how often the failure is unrecoverable in
  /// practice rather than a one-off.
  static let startupStoreReset = "startup_store_reset"

  // MARK: Device

  /// Device rotated between portrait and landscape.
  static let orientationChanged = "orientation_changed"

  // MARK: Consent

  /// The analytics setting was changed, from the Settings toggle or the first-run sheet.
  /// Carries `new_value` and, on an opt-out, `old_value`.
  ///
  /// On opt-out this is sent *before* the client is reset, while the person is still opted in —
  /// it is the only record that the opt-out happened. See spec §6.3.
  static let analyticsConsentChanged = "analytics_consent_changed"
}

// MARK: - Canonical property keys

/// Property-key constants, all `snake_case`. `nonisolated` for the same reason as `AnalyticsEvent`
/// above: they are strings, not state.
nonisolated enum AnalyticsProperty {
  // MARK: checklists_viewed

  /// Number of checklists in the list. Sent raw, not bucketed — Mixpanel handles numeric
  /// properties natively, and bucketing here would buy no privacy given `checklist_name` is sent.
  static let checklistsCount = "checklists_count"

  // MARK: checklist_viewed

  /// **Raw checklist name — user content.**
  ///
  /// The one free-text property this app sends, kept as an accepted risk rather than dropped or
  /// bucketed: it is the only thing that answers "what do people actually make checklists for?",
  /// and it is why the consent gate sits where it does. Documented at
  /// core-docs/analytics-spec.md §4.4; it is **not** a precedent for adding more user content.
  static let checklistName = "checklist_name"
  /// Character count of the checklist's notes field — never the text itself.
  static let notesLength = "notes_length"
  /// Number of items in the checklist.
  static let itemsCount = "items_count"
  /// Number of items that have non-empty notes. The note text is never sent.
  static let itemsWithNotesCount = "items_with_notes_count"

  // MARK: Errors and failures

  /// An `NSError`'s `domain`. A framework-authored constant, never user content.
  static let errorDomain = "error_domain"
  /// An `NSError`'s `code`. Int.
  static let errorCode = "error_code"
  /// Which save failed: `PersistenceOperation.rawValue`. `persistence_write_failed` only.
  static let errorOperation = "error_operation"

  // MARK: orientation_changed

  /// `portrait` or `landscape`. Face-up and face-down are filtered out rather than reported.
  static let orientation = "orientation"

  // MARK: analytics_consent_changed

  /// The setting's new value. Bool.
  static let newValue = "new_value"
  /// The setting's previous value, sent on an opt-out. Bool.
  static let oldValue = "old_value"

  // MARK: Super properties (spec §9.2)

  /// `CFBundleShortVersionString`. Sent separately from the build number so both can be filtered
  /// on independently — do not send `SettingsManager.versionBuildString`, which combines them and
  /// appends `- DEBUG`.
  static let appVersion = "app_version"
  /// `CFBundleVersion`.
  static let appBuild = "app_build"
  /// `phone` / `pad`. Near-constant given the app is iPhone-only; it distinguishes an iPad running
  /// the iPhone app from a real iPhone.
  static let deviceClass = "device_class"
  /// `Locale.current.identifier`.
  static let locale = "locale"
  /// `Locale.current.region?.identifier`.
  static let region = "region"
  /// `required` / `auto_optin`. Without this, a consent-driven measurement gap is
  /// indistinguishable from a real drop in usage — see spec §9.2.
  static let consentJurisdiction = "consent_jurisdiction"

  // MARK: People properties (spec §9.3)

  /// Set once, on the first identify.
  static let firstSeenAt = "first_seen_at"
  /// Refreshed on every `app_opened`.
  static let lastAppOpenAt = "last_app_open_at"
  /// Stamped on the opt-in transition.
  static let analyticsOptInAt = "analytics_opt_in_at"
  /// `0` / `1` / `2-3` / `4-7` / `8+`. This app's one cohort signal. Bucketed because profiles are
  /// what cohorts are built from; the raw count still rides on `checklists_viewed`.
  static let checklistsCountBucket = "checklists_count_bucket"
}
