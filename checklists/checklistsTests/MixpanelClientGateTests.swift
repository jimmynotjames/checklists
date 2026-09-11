//
//  MixpanelClientGateTests.swift
//  checklistsTests
//

@testable import checklists
import XCTest

/// Exercises `MixpanelAnalyticsClient`'s lazy-init contract against the **real class**, not a
/// simulation — see core-docs/analytics-spec.md §13 contract 9 and §7.2.
///
/// The opt-in check itself is `ConsentGatedAnalyticsClient`'s job (covered by `ConsentGateTests`)
/// — this class has no `isOptedIn` closure of its own. What is load-bearing here is that
/// `Mixpanel.initialize` truly is deferred to the first `track`/`identify` call and that `reset()`
/// discards the instance so a later call re-initializes, both observed through the `#if DEBUG`
/// `isSDKInitializedForTesting` seam rather than by reaching into `MixpanelInstance` directly.
nonisolated final class MixpanelClientGateTests: XCTestCase {
  /// Not a real project token, and deliberately **not** shaped like one (32 lowercase hex) —
  /// `MixpanelAnalyticsClient` never validates shape, only `MixpanelTokenSource` does, and that
  /// check happens before this class is ever constructed. A hex-shaped literal here would also
  /// trip the repo's gitleaks Mixpanel-token rule (analytics-spec.md §10), which carries no
  /// allowlist by design.
  private static let testToken = "unit-test-mixpanel-token-not-real"

  @MainActor
  func testInitLeavesSDKUninitialized() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    XCTAssertFalse(client.isSDKInitializedForTesting)
  }

  @MainActor
  func testFirstTrackInitializesTheSDK() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    client.track(AnalyticsEvent.appOpened, properties: nil)
    XCTAssertTrue(client.isSDKInitializedForTesting)
  }

  @MainActor
  func testSubsequentTrackCallsDoNotReinitialize() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    client.track(AnalyticsEvent.appOpened, properties: nil)
    XCTAssertTrue(client.isSDKInitializedForTesting)
    // A second and third call must not crash or replace the instance — there is no direct way to
    // observe "exactly once" from outside, but repeated calls staying initialized (rather than
    // toggling or trapping) is the externally visible half of that guarantee.
    client.track(AnalyticsEvent.checklistsViewed, properties: nil)
    client.track(AnalyticsEvent.settingsViewed, properties: nil)
    XCTAssertTrue(client.isSDKInitializedForTesting)
  }

  @MainActor
  func testIdentifyAlsoInitializesTheSDK() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    client.identify("some-distinct-id")
    XCTAssertTrue(client.isSDKInitializedForTesting)
  }

  @MainActor
  func testResetDiscardsTheInstance() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    client.track(AnalyticsEvent.appOpened, properties: nil)
    XCTAssertTrue(client.isSDKInitializedForTesting)
    client.reset()
    XCTAssertFalse(client.isSDKInitializedForTesting)
  }

  @MainActor
  func testTrackAfterResetReinitializes() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    client.track(AnalyticsEvent.appOpened, properties: nil)
    client.reset()
    XCTAssertFalse(client.isSDKInitializedForTesting)
    client.track(AnalyticsEvent.appOpened, properties: nil)
    XCTAssertTrue(client.isSDKInitializedForTesting)
  }

  @MainActor
  func testRefreshCohortPeoplePropertiesIsANoOpBeforeInitialization() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    // No SDK instance exists yet — this must not create one as a side effect.
    client.refreshCohortPeopleProperties(checklistsCount: 3)
    XCTAssertFalse(client.isSDKInitializedForTesting)
  }

  @MainActor
  func testSetAnalyticsOptInAtIsANoOpBeforeInitialization() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    client.setAnalyticsOptInAt()
    XCTAssertFalse(client.isSDKInitializedForTesting)
  }
}
