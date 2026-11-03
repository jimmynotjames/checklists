//
//  AnalyticsNames.swift
//  checklists
//

// MARK: - Canonical event names

/// Event-name constants: flat `snake_case`, `noun_pastTenseVerb`. Use these at every call site,
/// never a string literal, so a typo is a compile error rather than a duplicate-looking event.
/// Code-side mirror of core-docs/analytics-spec.md §Event catalog and §Property catalog — change
/// together, in the same PR.
/// `nonisolated` on the type: plain compile-time strings, kept off the target's MainActor default.
nonisolated enum AnalyticsEvent {
  static let appOpened = "app_opened"

  // MARK: Page views

  static let checklistsViewed = "checklists_viewed"
  static let checklistViewed = "checklist_viewed"
  static let settingsViewed = "settings_viewed"

  // MARK: Navigation out of the app

  static let rateAppTapped = "rate_app_tapped"
  static let feedbackTapped = "feedback_tapped"
  static let privacyPolicyTapped = "privacy_policy_tapped"

  // MARK: User actions

  static let checklistCreated = "checklist_created"
  static let checklistDuplicated = "checklist_duplicated"
  static let checklistItemsCopied = "checklist_items_copied"
  static let checklistItemsMoved = "checklist_items_moved"
  static let checklistCheckedItemsDeleted = "checklist_checked_items_deleted"
  static let checklistReset = "checklist_reset"
  static let checklistDeleted = "checklist_deleted"
  static let checklistReorderModeEntered = "checklist_reorder_mode_entered"
  static let checklistItemDuplicated = "checklist_item_duplicated"
  static let checklistsEditModeEntered = "checklists_edit_mode_entered"
  static let checklistsBulkActionPerformed = "checklists_bulk_action_performed"
  static let allChecklistsReset = "all_checklists_reset"
  static let checklistPDFExported = "checklist_pdf_exported"

  // MARK: Errors

  static let persistenceFatalError = "persistence_fatal_error"
  static let persistenceWriteFailed = "persistence_write_failed"
  static let startupFailed = "startup_failed"
  static let startupStoreReset = "startup_store_reset"
  static let legacyImportAbandoned = "legacy_import_abandoned"

  // MARK: iCloud sync

  static let icloudStatusChecked = "icloud_status_checked"
  static let cloudkitContainerFellBack = "cloudkit_container_fell_back"
  static let cloudkitSyncFailed = "cloudkit_sync_failed"

  // MARK: Rating prompt

  static let ratingPromptEligible = "rating_prompt_eligible"
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

  static let checklistName = "checklist_name"
  static let notesLength = "notes_length"
  static let itemsCount = "items_count"
  static let itemsWithNotesCount = "items_with_notes_count"

  // MARK: checklist_duplicated

  static let source = "source"

  // MARK: checklist_items_copied, checklist_items_moved

  static let destination = "destination"

  // MARK: checklists_bulk_action_performed

  static let bulkAction = "bulk_action"
  static let selectedCount = "selected_count"

  // MARK: checklist_pdf_exported

  static let checkedItemsCount = "checked_items_count"

  // MARK: Errors and failures

  static let errorDomain = "error_domain"
  static let errorCode = "error_code"
  static let errorOperation = "error_operation"
  static let startupStage = "startup_stage"

  // MARK: iCloud sync

  static let containerBacking = "container_backing"
  static let icloudAccount = "icloud_account"
  static let syncOperation = "sync_operation"

  static let orientation = "orientation"

  // MARK: analytics_consent_changed

  static let newValue = "new_value"
  static let oldValue = "old_value"

  // MARK: rating_prompt_requested

  static let timeSinceFirstEligibleBucket = "time_since_first_eligible_bucket"

  // MARK: Super properties

  static let appVersion = "app_version"
  static let appBuild = "app_build"
  static let deviceClass = "device_class"
  static let locale = "locale"
  static let region = "region"
  static let consentJurisdiction = "consent_jurisdiction"

  // MARK: People properties

  static let firstSeenAt = "first_seen_at"
  static let lastAppOpenAt = "last_app_open_at"
  static let analyticsOptInAt = "analytics_opt_in_at"
  static let checklistsCountBucket = "checklists_count_bucket"
  static let ratingPromptFirstEligibleAt = "rating_prompt_first_eligible_at"
  static let ratingPromptLastRequestedAt = "rating_prompt_last_requested_at"
}
