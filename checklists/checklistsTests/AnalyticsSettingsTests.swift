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
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())

    XCTAssertEqual(settings.analyticsOptIn, currentLocaleDefault)
  }

  @MainActor func testResolvedDefaultIsNotWrittenToTheStore() {
    let store = InMemoryKeyValueStore()
    _ = AnalyticsSettings(store: store)

    XCTAssertNil(
      store.object(forKey: AnalyticsSettings.analyticsOptInKey),
      "Writing the locale-resolved default would make every install look like it had already decided."
    )
  }

  @MainActor func testExplicitValueOverridesTheLocaleDefault() {
    let store = InMemoryKeyValueStore()
    let explicitValue = !currentLocaleDefault
    store.set(explicitValue, forKey: AnalyticsSettings.analyticsOptInKey)

    let settings = AnalyticsSettings(store: store)

    XCTAssertEqual(settings.analyticsOptIn, explicitValue)
  }

  @MainActor func testExplicitlySetIsFalseUntilAnExplicitWrite() {
    let store = InMemoryKeyValueStore()
    let settings = AnalyticsSettings(store: store)

    XCTAssertFalse(settings.analyticsOptInExplicitlySet)

    settings.analyticsOptIn = true

    XCTAssertTrue(settings.analyticsOptInExplicitlySet)
  }

  // MARK: - Launch stores

  @MainActor func testScreenshotLaunchThroughUITestArgumentSeedsExplicitOptOut() {
    assertScreenshotConsent(arguments: ["-UITests1"], environment: [:])
  }

  @MainActor func testScreenshotLaunchThroughTestEnvironmentSeedsExplicitOptOut() {
    assertScreenshotConsent(arguments: [], environment: ["IS_TESTING": "1"])
  }

  @MainActor func testOrdinaryTestLaunchLeavesConsentAbsent() {
    let store = AnalyticsSettings.makeStore(
      arguments: ["-UITests1"],
      environment: [:],
      persistentStore: InMemoryKeyValueStore()
    )
    let settings = AnalyticsSettings(store: store)

    XCTAssertFalse(settings.analyticsOptInExplicitlySet)
    XCTAssertNil(store.object(forKey: AnalyticsSettings.analyticsOptInKey))
  }

  @MainActor func testOrdinaryTestLaunchAfterScreenshotLaunchGetsFreshConsentState() {
    let screenshotStore = makeScreenshotStore(arguments: ["-UITests1"], environment: [:])
    let ordinaryStore = AnalyticsSettings.makeStore(
      arguments: ["-UITests1"],
      environment: [:],
      persistentStore: InMemoryKeyValueStore()
    )
    let screenshotSettings = AnalyticsSettings(store: screenshotStore)
    let ordinarySettings = AnalyticsSettings(store: ordinaryStore)

    #if DEBUG
      XCTAssertTrue(screenshotSettings.analyticsOptInExplicitlySet)
    #else
      XCTAssertFalse(screenshotSettings.analyticsOptInExplicitlySet)
    #endif
    XCTAssertFalse(ordinarySettings.analyticsOptInExplicitlySet)
  }

  @MainActor func testIncompleteScreenshotMetadataLeavesConsentAbsent() {
    let jsonOnlyStore = AnalyticsSettings.makeStore(
      arguments: ["-UITests1"],
      environment: [LaunchModeContainerFactory.screenshotSeedJSONKey: "{}"],
      persistentStore: InMemoryKeyValueStore()
    )
    let localeOnlyStore = AnalyticsSettings.makeStore(
      arguments: ["-UITests1"],
      environment: [LaunchModeContainerFactory.screenshotSeedLocaleKey: "de-DE"],
      persistentStore: InMemoryKeyValueStore()
    )
    let emptyLocaleStore = makeScreenshotStore(
      arguments: ["-UITests1"],
      environment: [LaunchModeContainerFactory.screenshotSeedLocaleKey: ""]
    )

    XCTAssertFalse(AnalyticsSettings(store: jsonOnlyStore).analyticsOptInExplicitlySet)
    XCTAssertFalse(AnalyticsSettings(store: localeOnlyStore).analyticsOptInExplicitlySet)
    XCTAssertFalse(AnalyticsSettings(store: emptyLocaleStore).analyticsOptInExplicitlySet)
  }

  @MainActor func testScreenshotMetadataCannotSeedANonTestLaunch() {
    let persistentStore = InMemoryKeyValueStore()
    let store = makeScreenshotStore(arguments: [], environment: [:], persistentStore: persistentStore)
    let settings = AnalyticsSettings(store: store)

    XCTAssertTrue(store === persistentStore)
    XCTAssertFalse(settings.analyticsOptInExplicitlySet)
  }

  // MARK: - distinct_id

  @MainActor func testDistinctIdIsAValidUUID() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())

    XCTAssertNotNil(UUID(uuidString: settings.analyticsDistinctId))
  }

  @MainActor func testDistinctIdIsStableAcrossASecondInstanceOverTheSameStore() {
    let store = InMemoryKeyValueStore()
    let first = AnalyticsSettings(store: store)
    let second = AnalyticsSettings(store: store)

    XCTAssertEqual(first.analyticsDistinctId, second.analyticsDistinctId)
  }

  @MainActor func testDistinctIdIsPersistedOnFirstGeneration() {
    let store = InMemoryKeyValueStore()
    let settings = AnalyticsSettings(store: store)

    XCTAssertEqual(
      store.object(forKey: AnalyticsSettings.analyticsDistinctIdKey) as? String,
      settings.analyticsDistinctId
    )
  }

  @MainActor private func assertScreenshotConsent(
    arguments: [String],
    environment: [String: String]
  ) {
    let store = makeScreenshotStore(arguments: arguments, environment: environment)
    let settings = AnalyticsSettings(store: store)

    #if DEBUG
      XCTAssertFalse(settings.analyticsOptIn)
      XCTAssertTrue(settings.analyticsOptInExplicitlySet)
    #else
      XCTAssertFalse(
        settings.analyticsOptInExplicitlySet,
        "Release builds must not contain screenshot consent seeding."
      )
    #endif
  }

  @MainActor private func makeScreenshotStore(
    arguments: [String],
    environment: [String: String],
    persistentStore: KeyValueStore = InMemoryKeyValueStore()
  ) -> KeyValueStore {
    var screenshotEnvironment = environment
    screenshotEnvironment[LaunchModeContainerFactory.screenshotSeedJSONKey] = "{}"
    screenshotEnvironment[LaunchModeContainerFactory.screenshotSeedLocaleKey] =
      screenshotEnvironment[LaunchModeContainerFactory.screenshotSeedLocaleKey] ?? "de-DE"
    return AnalyticsSettings.makeStore(
      arguments: arguments,
      environment: screenshotEnvironment,
      persistentStore: persistentStore
    )
  }
}
