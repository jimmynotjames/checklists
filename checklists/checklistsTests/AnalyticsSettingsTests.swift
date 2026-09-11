//
//  AnalyticsSettingsTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import XCTest

/// Covers `AnalyticsSettings`'s locale-aware opt-in default, its non-persistence, the explicit
/// override, and the stable, once-generated `distinct_id` (core-docs/analytics-spec.md §5, §6).
///
/// See the note on `AnalyticsTextTests` for the `nonisolated` class / `@MainActor` method
/// pattern.
nonisolated final class AnalyticsSettingsTests: XCTestCase {
  /// The exact jurisdiction lookup `AnalyticsSettings` itself uses. Comparing against it, rather
  /// than a hardcoded `true`/`false`, keeps this test correct regardless of which region the
  /// test runner actually resolves to — `ConsentJurisdictionTests` covers the strict-vs-auto-optin
  /// branch directly.
  private var currentLocaleDefault: Bool {
    ConsentJurisdiction.kind(for: Locale.current.region?.identifier) == .autoOptin
  }

  @MainActor func testDefaultMatchesTheCurrentLocalesJurisdiction() {
    let settings = AnalyticsSettings(store: MockKeyValueStore())

    XCTAssertEqual(settings.analyticsOptIn, currentLocaleDefault)
  }

  @MainActor func testResolvedDefaultIsNotWrittenToTheStore() {
    let store = MockKeyValueStore()
    _ = AnalyticsSettings(store: store)

    XCTAssertNil(
      store.object(forKey: AnalyticsSettings.analyticsOptInKey),
      "Writing the locale-resolved default would make every install look like it had already decided."
    )
  }

  @MainActor func testExplicitValueOverridesTheLocaleDefault() {
    let store = MockKeyValueStore()
    let explicitValue = !currentLocaleDefault
    store.set(explicitValue, forKey: AnalyticsSettings.analyticsOptInKey)

    let settings = AnalyticsSettings(store: store)

    XCTAssertEqual(settings.analyticsOptIn, explicitValue)
  }

  @MainActor func testExplicitlySetIsFalseUntilAnExplicitWrite() {
    let store = MockKeyValueStore()
    let settings = AnalyticsSettings(store: store)

    XCTAssertFalse(settings.analyticsOptInExplicitlySet)

    settings.analyticsOptIn = true

    XCTAssertTrue(settings.analyticsOptInExplicitlySet)
  }

  // MARK: - distinct_id

  @MainActor func testDistinctIdIsAValidUUID() {
    let settings = AnalyticsSettings(store: MockKeyValueStore())

    XCTAssertNotNil(UUID(uuidString: settings.analyticsDistinctId))
  }

  @MainActor func testDistinctIdIsStableAcrossASecondInstanceOverTheSameStore() {
    let store = MockKeyValueStore()
    let first = AnalyticsSettings(store: store)
    let second = AnalyticsSettings(store: store)

    XCTAssertEqual(first.analyticsDistinctId, second.analyticsDistinctId)
  }

  @MainActor func testDistinctIdIsPersistedOnFirstGeneration() {
    let store = MockKeyValueStore()
    let settings = AnalyticsSettings(store: store)

    XCTAssertEqual(
      store.object(forKey: AnalyticsSettings.analyticsDistinctIdKey) as? String,
      settings.analyticsDistinctId
    )
  }
}
