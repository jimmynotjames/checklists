//
//  AnalyticsNames.swift
//  checklists
//

// MARK: - Canonical event names

/// Event-name constants. All names are flat `snake_case`, `noun_pastTenseVerb`, matching the
/// convention in `budgets1`'s `AnalyticsEvent`. Use these at every call site — never a string
/// literal — so a typo is a compile error.
///
/// This enum and `AnalyticsProperty` below are the code-side mirror of the catalogs in
/// core-docs/analytics-spec.md §8 and §9. **Change them together**, in the same PR.
///
/// These were renamed when Flurry was removed. Nothing depended on the old names: the Flurry data
/// is not migrating anywhere, so there was no continuity to preserve. The old Flurry name is noted
/// on each constant for anyone reading historical Flurry exports; spec §14 has the full mapping.
enum AnalyticsEvent {
  // MARK: Session

  /// App brought to the foreground — cold launch or a return from background. **New** — Flurry
  /// had no equivalent event because `startSession` gave it sessions automatically. Mixpanel
  /// needs this explicitly. See `AppOpenTracker`.
  nonisolated static let appOpened = "app_opened"

  // MARK: Page views

  /// Checklists list shown. Flurry: `checklists_viewed` (unchanged).
  nonisolated static let checklistsViewed = "checklists_viewed"
  /// A single checklist opened. Flurry: `checklist_viewed` (unchanged).
  nonisolated static let checklistViewed = "checklist_viewed"
  /// Settings screen shown. Flurry: `settings_viewed` (unchanged).
  nonisolated static let settingsViewed = "settings_viewed"
  /// Main menu shown. Flurry: `main_menu_viewed` (unchanged).
  nonisolated static let mainMenuViewed = "main_menu_viewed"

  // MARK: Navigation out of the app

  /// "Rate in App Store" tapped. Flurry: `rate_in_app_store`.
  nonisolated static let rateAppTapped = "rate_app_tapped"
  /// "Send feedback" tapped. Flurry: `send_feedback`.
  nonisolated static let feedbackTapped = "feedback_tapped"
  /// Privacy policy opened. Flurry: `view_privacy_policy`.
  nonisolated static let privacyPolicyTapped = "privacy_policy_tapped"

  // MARK: User actions

  /// A new checklist was created. Flurry: `create_new_checklist`.
  nonisolated static let checklistCreated = "checklist_created"
  /// A checklist's items were all unchecked. Flurry: `reset_checklist`.
  nonisolated static let checklistReset = "checklist_reset"

  // MARK: Errors

  /// The persistent store could not be opened at all. Flurry: `realm/fatal_error`. Renamed off
  /// "realm" so the event survives a persistence-layer swap — which it since has.
  nonisolated static let persistenceFatalError = "persistence_fatal_error"
  /// A SwiftData save threw. Flurry: `realm/write_error`.
  nonisolated static let persistenceWriteFailed = "persistence_write_failed"
  /// Launch could not produce a usable store, so the retry screen was shown instead of the app.
  /// Covers all three causes — the container would not open, the one-time Realm import did not
  /// complete, or first-launch seeding would not save. New with the SwiftData migration; no
  /// Flurry predecessor, because the Realm build crashed here rather than recovering.
  nonisolated static let startupFailed = "startup_failed"
  /// The user gave up on that screen and wiped this device's stores to get a working app back.
  /// Paired with `startup_failed`, the ratio says how often the failure is unrecoverable in
  /// practice rather than a one-off.
  nonisolated static let startupStoreReset = "startup_store_reset"

  // MARK: Device

  /// Device rotated between portrait and landscape. Flurry: `orientation_changed` (unchanged),
  /// but it no longer carries `ui_idiom` — that became the `device_class` super property.
  nonisolated static let orientationChanged = "orientation_changed"

  // MARK: Consent

  /// The analytics setting was changed, from the Settings toggle or the first-run sheet.
  /// Carries `new_value` and, on an opt-out, `old_value`. New; no Flurry predecessor.
  ///
  /// On opt-out this is sent *before* the client is reset, while the person is still opted in —
  /// it is the only record that the opt-out happened. See spec §6.3.
  nonisolated static let analyticsConsentChanged = "analytics_consent_changed"
}

// MARK: - Canonical property keys

/// Property-key constants, all `snake_case`. Matches `budgets1`'s `AnalyticsProperty`.
enum AnalyticsProperty {
  // MARK: checklists_viewed

  /// Number of checklists in the list. Sent raw, not bucketed. Flurry: `num_checklists`.
  nonisolated static let checklistsCount = "checklists_count"

  // MARK: checklist_viewed

  /// **Raw checklist name — user content.** Flurry: `name`.
  ///
  /// The one free-text property this app sends, retained as an accepted risk rather than dropped
  /// or bucketed, mirroring the way `budgets1` allow-lists `budget_name`. It is what makes "what
  /// do people make checklists for?" answerable, and it is why the consent gate is placed where
  /// it is. Documented at core-docs/analytics-spec.md §4.4; it is **not** a precedent for adding
  /// more user content.
  nonisolated static let checklistName = "checklist_name"
  /// Character count of the checklist's notes field — never the text. Flurry: `notesLength`, the
  /// one camelCase key in the old catalog.
  nonisolated static let notesLength = "notes_length"
  /// Number of items in the checklist. Flurry: `num_items`.
  nonisolated static let itemsCount = "items_count"
  /// Number of items that have non-empty notes. Flurry: `num_items_with_notes`.
  nonisolated static let itemsWithNotesCount = "items_with_notes_count"

  // MARK: Errors and failures

  /// Error description, truncated by `AnalyticsText.truncated`. Flurry: `error` (unchanged).
  nonisolated static let error = "error"

  // MARK: orientation_changed

  /// `portrait` or `landscape`. Flurry: `orientation` (unchanged).
  nonisolated static let orientation = "orientation"

  // MARK: analytics_consent_changed

  /// The setting's new value. Bool.
  nonisolated static let newValue = "new_value"
  /// The setting's previous value, sent on an opt-out. Bool.
  nonisolated static let oldValue = "old_value"

  // MARK: Super properties (spec §9.2)

  /// `CFBundleShortVersionString`. Sent separately from the build number, unlike Flurry's
  /// combined `withAppVersion` string, so both can be filtered on.
  nonisolated static let appVersion = "app_version"
  /// `CFBundleVersion`.
  nonisolated static let appBuild = "app_build"
  /// `phone` / `pad`. Replaces the old per-event `ui_idiom`, which never varied within an install.
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
  /// `0` / `1` / `2-3` / `4-7` / `8+`. This app's one cohort signal. Bucketed because profiles
  /// are what cohorts are built from; the raw count still rides on `checklists_viewed`.
  nonisolated static let checklistsCountBucket = "checklists_count_bucket"
}
