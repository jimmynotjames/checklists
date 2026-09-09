//
//  AnalyticsNamesTests.swift
//  checklistsTests
//

@testable import checklists
import XCTest

/// Guards the naming convention for the event and property catalogs (analytics-spec.md §8, §9).
///
/// Cheap, but it is the regression net for a rename: two constants that collide would silently
/// merge two events in Mixpanel, and a stray capital or space would create a second event that
/// looks like the first in a dashboard listing.
///
/// See the note on `AnalyticsTextTests` for the `nonisolated` class / `@MainActor` method pattern.
nonisolated final class AnalyticsNamesTests: XCTestCase {
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
    AnalyticsEvent.checklistReset,
    AnalyticsEvent.persistenceFatalError,
    AnalyticsEvent.persistenceWriteFailed,
    AnalyticsEvent.startupFailed,
    AnalyticsEvent.startupStoreReset,
    AnalyticsEvent.orientationChanged,
    AnalyticsEvent.analyticsConsentChanged,
  ]

  private static let allProperties: [String] = [
    AnalyticsProperty.checklistsCount,
    AnalyticsProperty.checklistName,
    AnalyticsProperty.notesLength,
    AnalyticsProperty.itemsCount,
    AnalyticsProperty.itemsWithNotesCount,
    AnalyticsProperty.error,
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
  ]

  /// Matches the spec's stated convention: flat `snake_case`, starting with a lowercase letter.
  private func assertSnakeCase(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertFalse(name.isEmpty, "Empty name.", file: file, line: line)
    XCTAssertNotNil(name.first.map { $0.isLowercase && $0.isLetter }, file: file, line: line)
    XCTAssertTrue(
      name.allSatisfy { ($0.isLowercase && $0.isLetter) || $0.isNumber || $0 == "_" },
      "\"\(name)\" is not flat snake_case.",
      file: file,
      line: line
    )
  }

  @MainActor func testEventNamesAreDistinct() {
    XCTAssertEqual(
      Set(Self.allEvents).count,
      Self.allEvents.count,
      "Two events share a name; they would merge in Mixpanel."
    )
  }

  @MainActor func testEventNamesAreSnakeCase() {
    for name in Self.allEvents {
      assertSnakeCase(name)
    }
  }

  @MainActor func testPropertyKeysAreDistinct() {
    XCTAssertEqual(Set(Self.allProperties).count, Self.allProperties.count)
  }

  @MainActor func testPropertyKeysAreSnakeCase() {
    for name in Self.allProperties {
      assertSnakeCase(name)
    }
  }

  /// Pinned literally: this event is what every reach, session and retention number on the
  /// dashboards is built from, so a rename would silently empty them.
  @MainActor func testAppOpenedNameIsPinned() {
    XCTAssertEqual(AnalyticsEvent.appOpened, "app_opened")
  }
}
