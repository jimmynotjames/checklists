//
//  AnalyticsSettingsTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import Testing

/// Covers `AnalyticsSettings`'s locale-aware opt-in default, its non-persistence, the explicit
/// override, and the stable, once-generated `distinct_id` (core-docs/analytics-spec.md §Identity, §Consent).
@Suite("Analytics settings")
struct AnalyticsSettingsTests {
  /// The exact jurisdiction lookup `AnalyticsSettings` itself uses. Comparing against it, rather
  /// than a hardcoded `true`/`false`, keeps this test correct regardless of which region the
  /// test runner actually resolves to — `ConsentJurisdictionTests` covers the strict-vs-auto-optin
  /// branch directly.
  private var currentLocaleDefault: Bool {
    ConsentJurisdiction.kind(for: Locale.current.region?.identifier) == .autoOptin
  }

  @Test("the default opt-in matches the current locale's jurisdiction")
  func defaultMatchesTheCurrentLocalesJurisdiction() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())

    #expect(settings.analyticsOptIn == currentLocaleDefault)
  }

  @Test("the locale-resolved default is not written to the store")
  func resolvedDefaultIsNotWrittenToTheStore() {
    let store = InMemoryKeyValueStore()
    _ = AnalyticsSettings(store: store)

    #expect(
      store.object(forKey: AnalyticsSettings.analyticsOptInKey) == nil,
      "Writing the locale-resolved default would make every install look like it had already decided."
    )
  }

  @Test("an explicit value overrides the locale default")
  func explicitValueOverridesTheLocaleDefault() {
    let store = InMemoryKeyValueStore()
    let explicitValue = !currentLocaleDefault
    store.set(explicitValue, forKey: AnalyticsSettings.analyticsOptInKey)

    let settings = AnalyticsSettings(store: store)

    #expect(settings.analyticsOptIn == explicitValue)
  }

  @Test("analyticsOptInExplicitlySet is false until an explicit write")
  func explicitlySetIsFalseUntilAnExplicitWrite() {
    let store = InMemoryKeyValueStore()
    let settings = AnalyticsSettings(store: store)

    #expect(!settings.analyticsOptInExplicitlySet)

    settings.analyticsOptIn = true

    #expect(settings.analyticsOptInExplicitlySet)
  }

  // MARK: - Launch stores

  @Test("a screenshot launch through the UI test argument seeds an explicit opt-out")
  func screenshotLaunchThroughUITestArgumentSeedsExplicitOptOut() {
    assertScreenshotConsent(arguments: ["-UITests1"], environment: [:])
  }

  @Test("a screenshot launch through the test environment variable seeds an explicit opt-out")
  func screenshotLaunchThroughTestEnvironmentSeedsExplicitOptOut() {
    assertScreenshotConsent(arguments: [], environment: ["IS_TESTING": "1"])
  }

  @Test("an ordinary test launch leaves consent absent")
  func ordinaryTestLaunchLeavesConsentAbsent() {
    let store = AnalyticsSettings.makeStore(
      arguments: ["-UITests1"],
      environment: [:],
      persistentStore: InMemoryKeyValueStore()
    )
    let settings = AnalyticsSettings(store: store)

    #expect(!settings.analyticsOptInExplicitlySet)
    #expect(store.object(forKey: AnalyticsSettings.analyticsOptInKey) == nil)
  }

  @Test("an ordinary test launch after a screenshot launch gets fresh consent state")
  func ordinaryTestLaunchAfterScreenshotLaunchGetsFreshConsentState() {
    let screenshotStore = makeScreenshotStore(arguments: ["-UITests1"], environment: [:])
    let ordinaryStore = AnalyticsSettings.makeStore(
      arguments: ["-UITests1"],
      environment: [:],
      persistentStore: InMemoryKeyValueStore()
    )
    let screenshotSettings = AnalyticsSettings(store: screenshotStore)
    let ordinarySettings = AnalyticsSettings(store: ordinaryStore)

    #if DEBUG
      #expect(screenshotSettings.analyticsOptInExplicitlySet)
    #else
      #expect(!screenshotSettings.analyticsOptInExplicitlySet)
    #endif
    #expect(!ordinarySettings.analyticsOptInExplicitlySet)
  }

  @Test("incomplete screenshot metadata leaves consent absent")
  func incompleteScreenshotMetadataLeavesConsentAbsent() {
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

    #expect(!AnalyticsSettings(store: jsonOnlyStore).analyticsOptInExplicitlySet)
    #expect(!AnalyticsSettings(store: localeOnlyStore).analyticsOptInExplicitlySet)
    #expect(!AnalyticsSettings(store: emptyLocaleStore).analyticsOptInExplicitlySet)
  }

  @Test("screenshot metadata cannot seed a non-test launch")
  func screenshotMetadataCannotSeedANonTestLaunch() {
    let persistentStore = InMemoryKeyValueStore()
    let store = makeScreenshotStore(arguments: [], environment: [:], persistentStore: persistentStore)
    let settings = AnalyticsSettings(store: store)

    #expect(store === persistentStore)
    #expect(!settings.analyticsOptInExplicitlySet)
  }

  // MARK: - distinct_id

  @Test("the distinct id is a valid UUID")
  func distinctIdIsAValidUUID() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())

    #expect(UUID(uuidString: settings.analyticsDistinctId) != nil)
  }

  @Test("the distinct id is stable across a second instance over the same store")
  func distinctIdIsStableAcrossASecondInstanceOverTheSameStore() {
    let store = InMemoryKeyValueStore()
    let first = AnalyticsSettings(store: store)
    let second = AnalyticsSettings(store: store)

    #expect(first.analyticsDistinctId == second.analyticsDistinctId)
  }

  @Test("the distinct id is persisted on first generation")
  func distinctIdIsPersistedOnFirstGeneration() {
    let store = InMemoryKeyValueStore()
    let settings = AnalyticsSettings(store: store)

    #expect(
      store.object(forKey: AnalyticsSettings.analyticsDistinctIdKey) as? String == settings.analyticsDistinctId
    )
  }

  private func assertScreenshotConsent(
    arguments: [String],
    environment: [String: String]
  ) {
    let store = makeScreenshotStore(arguments: arguments, environment: environment)
    let settings = AnalyticsSettings(store: store)

    #if DEBUG
      #expect(!settings.analyticsOptIn)
      #expect(settings.analyticsOptInExplicitlySet)
    #else
      #expect(
        !settings.analyticsOptInExplicitlySet,
        "Release builds must not contain screenshot consent seeding."
      )
    #endif
  }

  private func makeScreenshotStore(
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
