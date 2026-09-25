//
//  AnalyticsNamesTests.swift
//  checklistsTests
//

@testable import checklists
import Testing

/// Guards the naming convention for the event and property catalogs (analytics-spec.md §Event catalog, §Property catalog).
///
/// Cheap, but it is the regression net for a rename: two constants that collide would silently
/// merge two events in Mixpanel, and a stray capital or space would create a second event that
/// looks like the first in a dashboard listing.
@Suite("Analytics event and property naming")
struct AnalyticsNamesTests {
  /// Every event the app can emit. Add new events here when adding them to `AnalyticsEvent`.
  private static let allEvents: [String] = [
    AnalyticsEvent.appOpened,
    AnalyticsEvent.checklistsViewed,
    AnalyticsEvent.checklistViewed,
    AnalyticsEvent.settingsViewed,
    AnalyticsEvent.mainMenuViewed,
    AnalyticsEvent.rateAppTapped,
    AnalyticsEvent.feedbackTapped,
    AnalyticsEvent.privacyPolicyTapped,
    AnalyticsEvent.checklistCreated,
    AnalyticsEvent.checklistDuplicated,
    AnalyticsEvent.checklistItemsCopied,
    AnalyticsEvent.checklistReset,
    AnalyticsEvent.checklistDeleted,
    AnalyticsEvent.checklistsEditModeEntered,
    AnalyticsEvent.checklistsBulkActionPerformed,
    AnalyticsEvent.persistenceFatalError,
    AnalyticsEvent.persistenceWriteFailed,
    AnalyticsEvent.startupFailed,
    AnalyticsEvent.startupStoreReset,
    AnalyticsEvent.legacyImportAbandoned,
    AnalyticsEvent.icloudStatusChecked,
    AnalyticsEvent.cloudkitContainerFellBack,
    AnalyticsEvent.cloudkitSyncFailed,
    AnalyticsEvent.orientationChanged,
    AnalyticsEvent.analyticsConsentChanged,
    AnalyticsEvent.ratingPromptEligible,
    AnalyticsEvent.ratingPromptRequested,
  ]

  private static let allProperties: [String] = [
    AnalyticsProperty.checklistsCount,
    AnalyticsProperty.checklistName,
    AnalyticsProperty.notesLength,
    AnalyticsProperty.itemsCount,
    AnalyticsProperty.itemsWithNotesCount,
    AnalyticsProperty.source,
    AnalyticsProperty.destination,
    AnalyticsProperty.bulkAction,
    AnalyticsProperty.selectedCount,
    AnalyticsProperty.errorDomain,
    AnalyticsProperty.errorCode,
    AnalyticsProperty.errorOperation,
    AnalyticsProperty.startupStage,
    AnalyticsProperty.containerBacking,
    AnalyticsProperty.icloudAccount,
    AnalyticsProperty.syncOperation,
    AnalyticsProperty.orientation,
    AnalyticsProperty.newValue,
    AnalyticsProperty.oldValue,
    AnalyticsProperty.appVersion,
    AnalyticsProperty.appBuild,
    AnalyticsProperty.deviceClass,
    AnalyticsProperty.locale,
    AnalyticsProperty.region,
    AnalyticsProperty.consentJurisdiction,
    AnalyticsProperty.firstSeenAt,
    AnalyticsProperty.lastAppOpenAt,
    AnalyticsProperty.analyticsOptInAt,
    AnalyticsProperty.checklistsCountBucket,
    AnalyticsProperty.timeSinceFirstEligibleBucket,
    AnalyticsProperty.ratingPromptFirstEligibleAt,
    AnalyticsProperty.ratingPromptLastRequestedAt,
  ]

  /// Matches the spec's stated convention: flat `snake_case`, starting with a lowercase letter.
  private func assertSnakeCase(_ name: String, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(!name.isEmpty, "Empty name.", sourceLocation: sourceLocation)
    // `.map` on a non-nil optional always yields `.some`, so this has to compare the value —
    // otherwise a leading underscore or digit passes, which `allSatisfy` below also permits.
    #expect(
      name.first?.isLowercase == true,
      "\"\(name)\" must start with a lowercase letter.",
      sourceLocation: sourceLocation
    )
    #expect(
      name.allSatisfy { ($0.isLowercase && $0.isLetter) || $0.isNumber || $0 == "_" },
      "\"\(name)\" is not flat snake_case.",
      sourceLocation: sourceLocation
    )
  }

  @Test("no two analytics events share a name")
  func eventNamesAreDistinct() {
    #expect(
      Set(Self.allEvents).count == Self.allEvents.count,
      "Two events share a name; they would merge in Mixpanel."
    )
  }

  @Test("every analytics event name is flat snake_case")
  func eventNamesAreSnakeCase() {
    for name in Self.allEvents {
      assertSnakeCase(name)
    }
  }

  @Test("no two analytics property keys share a name")
  func propertyKeysAreDistinct() {
    #expect(Set(Self.allProperties).count == Self.allProperties.count)
  }

  @Test("every analytics property key is flat snake_case")
  func propertyKeysAreSnakeCase() {
    for name in Self.allProperties {
      assertSnakeCase(name)
    }
  }

  /// Pinned literally: this event is what every reach, session and retention number on the
  /// dashboards is built from, so a rename would silently empty them.
  @Test("the app_opened event name is pinned literally")
  func appOpenedNameIsPinned() {
    #expect(AnalyticsEvent.appOpened == "app_opened")
  }

  /// `error_operation` transmits `PersistenceOperation.rawValue`, so the Swift case names *are* the
  /// analytics vocabulary — renaming a case silently changes what the dashboards group by. Pinned
  /// here because no test can arrange a real save failure, so this is the only
  /// place the value set is guarded. Update analytics-spec.md §Per-event properties in the same change.
  @Test("the persistence operation values sent as error_operation are pinned")
  func persistenceOperationValuesArePinned() {
    let sent = Set(PersistenceOperation.allCases.map(\.rawValue))
    #expect(sent == [
      "checklistEdit", "itemEdit", "itemUpdate", "reorder", "delete", "legacyImport", "sampleSeed",
      "dedupe",
    ])
  }

  /// `startup_stage` transmits `ContainerCreationFailure.Stage.rawValue`, so the same rule as above
  /// applies: the case names *are* the analytics vocabulary. Update analytics-spec.md §Per-event
  /// properties in the same change.
  @Test("the startup stage values sent as startup_stage are pinned")
  func startupStageValuesArePinned() {
    let sent = Set(ContainerCreationFailure.Stage.allCases.map(\.rawValue))
    #expect(sent == ["store_open", "legacy_import", "first_launch_seed"])
  }

  /// `source` transmits `ChecklistDuplicationSource.rawValue`, so the same rule as above applies:
  /// the case names *are* the analytics vocabulary. Update analytics-spec.md §Per-event properties
  /// in the same change.
  @Test("the duplication source values sent as source are pinned")
  func duplicationSourceValuesArePinned() {
    #expect(ChecklistDuplicationSource.menu.rawValue == "menu")
    #expect(ChecklistDuplicationSource.swipe.rawValue == "swipe")
  }

  /// `destination` transmits `CheckedItemsCopyDestination.rawValue`. Its raw values are spelled out
  /// rather than derived from the case names, so this pins what the dashboards actually group by.
  /// Update analytics-spec.md §Per-event properties in the same change.
  @Test("the copy destination values sent as destination are pinned")
  func copyDestinationValuesArePinned() {
    #expect(CheckedItemsCopyDestination.newChecklist.rawValue == "new")
    #expect(CheckedItemsCopyDestination.existingChecklist.rawValue == "existing")
  }

  /// `bulk_action` transmits `ChecklistsBulkAction.rawValue`, the case names. Update
  /// analytics-spec.md §Per-event properties in the same change.
  @Test("the bulk action values sent as bulk_action are pinned")
  func bulkActionValuesArePinned() {
    #expect(ChecklistsBulkAction.delete.rawValue == "delete")
    #expect(ChecklistsBulkAction.duplicate.rawValue == "duplicate")
    #expect(ChecklistsBulkAction.reset.rawValue == "reset")
  }

  /// `container_backing` transmits `ContainerBacking.rawValue`. Update analytics-spec.md
  /// §Per-event properties in the same change.
  @Test("the container backing values sent as container_backing are pinned")
  func containerBackingValuesArePinned() {
    #expect(ContainerBacking.cloudKit.rawValue == "cloudkit")
    #expect(ContainerBacking.localFallback.rawValue == "local_fallback")
  }

  /// `icloud_account` transmits `SyncStatus.AccountStatus.rawValue` (`.checking` is never sent).
  /// Update analytics-spec.md §Per-event properties in the same change.
  @Test("the icloud account values sent as icloud_account are pinned")
  func icloudAccountValuesArePinned() {
    #expect(Set(SyncStatus.AccountStatus.allCases.map(\.rawValue)) == [
      "checking", "available", "no_account", "restricted", "temporarily_unavailable", "could_not_determine",
    ])
  }

  /// `sync_operation` transmits `SyncOperation.rawValue`. Update analytics-spec.md §Per-event
  /// properties in the same change.
  @Test("the sync operation values sent as sync_operation are pinned")
  func syncOperationValuesArePinned() {
    #expect(Set(SyncOperation.allCases.map(\.rawValue)) == ["setup", "import", "export"])
  }
}
