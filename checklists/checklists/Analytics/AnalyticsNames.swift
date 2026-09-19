//
//  AnalyticsNames.swift
//  checklists
//

// MARK: - Canonical event names

/// Event-name constants: flat `snake_case`, `noun_pastTenseVerb`. Use these at every call site,
/// never a string literal, so a typo is a compile error rather than a duplicate-looking event.
/// Code-side mirror of core-docs/analytics-spec.md §8/§9 — change together, in the same PR.
/// `nonisolated` on the type: plain compile-time strings, kept off the target's MainActor default.
nonisolated enum AnalyticsEvent {
  static let appOpened = "app_opened"

  // MARK: Page views

  static let checklistsViewed = "checklists_viewed"
  static let checklistViewed = "checklist_viewed"
  static let settingsViewed = "settings_viewed"
  static let mainMenuViewed = "main_menu_viewed"

  // MARK: Navigation out of the app

  static let rateAppTapped = "rate_app_tapped"
  static let feedbackTapped = "feedback_tapped"
  static let privacyPolicyTapped = "privacy_policy_tapped"

  // MARK: User actions

  static let checklistCreated = "checklist_created"
  /// Kept apart from `checklistCreated` rather than folded into it: duplicating is a third route
  /// alongside creating and resetting, and merging them would blur the reuse-vs-disposable split
  /// those two exist to measure (spec §3.5).
  static let checklistDuplicated = "checklist_duplicated"
  static let checklistReset = "checklist_reset"
  static let checklistDeleted = "checklist_deleted"

  // MARK: Errors

  static let persistenceFatalError = "persistence_fatal_error"
  static let persistenceWriteFailed = "persistence_write_failed"
  static let startupFailed = "startup_failed"
  static let startupStoreReset = "startup_store_reset"

  // MARK: Rating prompt

  /// Not an engagement-pressure event (§2 constraint 7): measures when the app's own bar is
  /// reached, not how to push anyone over it.
  static let ratingPromptEligible = "rating_prompt_eligible"
  /// StoreKit reports neither whether it showed the dialog nor what the person chose, so there is
  /// no `shown` or `resolved` event — do not manufacture one with a custom pre-prompt.
  static let ratingPromptRequested = "rating_prompt_requested"

  static let orientationChanged = "orientation_changed"

  // MARK: Consent

  static let analyticsConsentChanged = "analytics_consent_changed"
}

// MARK: - Canonical property keys

/// Property-key constants, all `snake_case`. `nonisolated` for the same reason as `AnalyticsEvent`
/// above: they are strings, not state.
nonisolated enum AnalyticsProperty {
  static let checklistsCount = "checklists_count"

  // MARK: checklist_viewed

  /// **Raw checklist name — user content.** The one free-text property this app sends, kept as an
  /// accepted risk rather than dropped or bucketed — see core-docs/analytics-spec.md §4.4. Not a
  /// precedent for adding more user content.
  static let checklistName = "checklist_name"
  static let notesLength = "notes_length"
  static let itemsCount = "items_count"
  static let itemsWithNotesCount = "items_with_notes_count"

  // MARK: checklist_duplicated

  /// Which affordance started it: `menu` or `swipe`. The two entry points are far apart in effort,
  /// so a single count would not say whether either is worth keeping.
  static let source = "source"

  // MARK: Errors and failures

  static let errorDomain = "error_domain"
  static let errorCode = "error_code"
  /// Which save failed: `PersistenceOperation.rawValue`. `persistence_write_failed` only.
  static let errorOperation = "error_operation"

  static let orientation = "orientation"

  // MARK: analytics_consent_changed

  static let newValue = "new_value"
  static let oldValue = "old_value"

  // MARK: rating_prompt_requested

  /// `<1d` / `<7d` / `<30d` / `30d+` between first eligibility and the request. Bucketed because
  /// an exact interval on an event answers nothing a bucket does not; the exact moments live on
  /// the profile.
  static let timeSinceFirstEligibleBucket = "time_since_first_eligible_bucket"

  // MARK: Super properties (spec §9.2)

  /// Do not send `SettingsManager.versionBuildString` here — it combines version and build and
  /// appends `- DEBUG`.
  static let appVersion = "app_version"
  static let appBuild = "app_build"
  static let deviceClass = "device_class"
  static let locale = "locale"
  static let region = "region"
  /// `required` / `auto_optin`. Without this, a consent-driven measurement gap is
  /// indistinguishable from a real drop in usage — see spec §9.2.
  static let consentJurisdiction = "consent_jurisdiction"

  // MARK: People properties (spec §9.3)

  static let firstSeenAt = "first_seen_at"
  static let lastAppOpenAt = "last_app_open_at"
  static let analyticsOptInAt = "analytics_opt_in_at"
  /// `0` / `1` / `2-3` / `4-7` / `8+`. This app's one cohort signal. Bucketed because profiles are
  /// what cohorts are built from; the raw count still rides on `checklists_viewed`.
  static let checklistsCountBucket = "checklists_count_bucket"
  static let ratingPromptFirstEligibleAt = "rating_prompt_first_eligible_at"
  /// No outcome is stored: StoreKit reports none.
  static let ratingPromptLastRequestedAt = "rating_prompt_last_requested_at"
}
