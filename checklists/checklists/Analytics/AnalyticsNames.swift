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
/// Declared `nonisolated` because SwiftData `@Model` types are not MainActor: without it, a model
/// extension that assembles an event's properties cannot reach these names.
enum AnalyticsEvent {
  // MARK: Session

  /// App brought to the foreground — a cold launch or a return from background.
  ///
  /// Mixpanel derives sessions server-side from this event, so it has to be sent explicitly on
  /// every foreground rather than only at launch. `AppOpenTracker` decides which scene-phase
  /// transitions qualify.
  nonisolated static let appOpened = "app_opened"

  // MARK: Page views

  /// Checklists list shown. Carries `checklists_count`.
  nonisolated static let checklistsViewed = "checklists_viewed"
  /// A single checklist opened. Carries the checklist's name and its size — see
  /// `Checklist.analyticsViewedProperties`.
  nonisolated static let checklistViewed = "checklist_viewed"
  /// Settings screen shown.
  nonisolated static let settingsViewed = "settings_viewed"
  /// Main menu shown.
  nonisolated static let mainMenuViewed = "main_menu_viewed"

  // MARK: Navigation out of the app

  /// "Rate in App Store" tapped.
  nonisolated static let rateAppTapped = "rate_app_tapped"
  /// "Send feedback" tapped, from either the main menu or the startup-failure screen.
  nonisolated static let feedbackTapped = "feedback_tapped"
  /// Privacy policy opened.
  nonisolated static let privacyPolicyTapped = "privacy_policy_tapped"

  // MARK: User actions

  /// A new checklist was created.
  nonisolated static let checklistCreated = "checklist_created"
  /// Every item in a checklist was unchecked at once.
  ///
  /// Read against `checklist_created`: resetting says people reuse a checklist, creating says they
  /// treat them as disposable.
  nonisolated static let checklistReset = "checklist_reset"

  // MARK: Errors

  /// The persistent store could not be opened at all.
  ///
  /// Named for persistence rather than for any one storage engine, so it survives a swap of the
  /// layer underneath. Treat its count as a floor: the app stops immediately afterwards, so the
  /// event often never reaches the network. `AppLog.cloudKit` is the complete record.
  nonisolated static let persistenceFatalError = "persistence_fatal_error"
  /// A save threw.
  nonisolated static let persistenceWriteFailed = "persistence_write_failed"
  /// Launch could not produce a usable store, so the retry screen was shown instead of the app.
  ///
  /// Covers all three causes — the container would not open, the one-time legacy import did not
  /// complete, or first-launch seeding would not save — because the user-facing outcome is the
  /// same for all three. No data has been lost when this fires.
  nonisolated static let startupFailed = "startup_failed"
  /// The user gave up on that screen and wiped this device's stores to get a working app back.
  ///
  /// Paired with `startup_failed`, the ratio says how often the failure is unrecoverable in
  /// practice rather than a one-off.
  nonisolated static let startupStoreReset = "startup_store_reset"

  // MARK: Device

  /// Device rotated between portrait and landscape.
  nonisolated static let orientationChanged = "orientation_changed"

  // MARK: Consent

  /// The analytics setting was changed, from the Settings toggle or the first-run sheet.
  /// Carries `new_value` and, on an opt-out, `old_value`.
  ///
  /// On opt-out this is sent *before* the client is reset, while the person is still opted in —
  /// it is the only record that the opt-out happened. See spec §6.3.
  nonisolated static let analyticsConsentChanged = "analytics_consent_changed"
}

// MARK: - Canonical property keys

/// Property-key constants, all `snake_case`. `nonisolated` for the same reason as `AnalyticsEvent`.
enum AnalyticsProperty {
  // MARK: checklists_viewed

  /// Number of checklists in the list. Sent raw, not bucketed — Mixpanel handles numeric
  /// properties natively, and bucketing here would buy no privacy given `checklist_name` is sent.
  nonisolated static let checklistsCount = "checklists_count"

  // MARK: checklist_viewed

  /// **Raw checklist name — user content.**
  ///
  /// The one free-text property this app sends, kept as an accepted risk rather than dropped or
  /// bucketed: it is the only thing that answers "what do people actually make checklists for?",
  /// and it is why the consent gate sits where it does. Documented at
  /// core-docs/analytics-spec.md §4.4; it is **not** a precedent for adding more user content.
  nonisolated static let checklistName = "checklist_name"
  /// Character count of the checklist's notes field — never the text itself.
  nonisolated static let notesLength = "notes_length"
  /// Number of items in the checklist.
  nonisolated static let itemsCount = "items_count"
  /// Number of items that have non-empty notes. The note text is never sent.
  nonisolated static let itemsWithNotesCount = "items_with_notes_count"

  // MARK: Errors and failures

  /// Error description, truncated by `AnalyticsText.truncated`.
  nonisolated static let error = "error"

  // MARK: orientation_changed

  /// `portrait` or `landscape`. Face-up and face-down are filtered out rather than reported.
  nonisolated static let orientation = "orientation"

  // MARK: analytics_consent_changed

  /// The setting's new value. Bool.
  nonisolated static let newValue = "new_value"
  /// The setting's previous value, sent on an opt-out. Bool.
  nonisolated static let oldValue = "old_value"

  // MARK: Super properties (spec §9.2)

  /// `CFBundleShortVersionString`. Sent separately from the build number so both can be filtered
  /// on independently — do not send `SettingsManager.versionBuildString`, which combines them and
  /// appends `- DEBUG`.
  nonisolated static let appVersion = "app_version"
  /// `CFBundleVersion`.
  nonisolated static let appBuild = "app_build"
  /// `phone` / `pad`. Near-constant given the app is iPhone-only; it distinguishes an iPad running
  /// the iPhone app from a real iPhone.
  nonisolated static let deviceClass = "device_class"
  /// `Locale.current.identifier`.
  nonisolated static let locale = "locale"
  /// `Locale.current.region?.identifier`.
  nonisolated static let region = "region"
  /// `required` / `auto_optin`. Without this, a consent-driven measurement gap is
  /// indistinguishable from a real drop in usage — see spec §9.2.
  nonisolated static let consentJurisdiction = "consent_jurisdiction"

  // MARK: People properties (spec §9.3)

  /// Set once, on the first identify.
  nonisolated static let firstSeenAt = "first_seen_at"
  /// Refreshed on every `app_opened`.
  nonisolated static let lastAppOpenAt = "last_app_open_at"
  /// Stamped on the opt-in transition.
  nonisolated static let analyticsOptInAt = "analytics_opt_in_at"
  /// `0` / `1` / `2-3` / `4-7` / `8+`. This app's one cohort signal. Bucketed because profiles are
  /// what cohorts are built from; the raw count still rides on `checklists_viewed`.
  nonisolated static let checklistsCountBucket = "checklists_count_bucket"
}
