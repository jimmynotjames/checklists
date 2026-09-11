//
//  MixpanelClientGateTests.swift
//  checklistsTests
//

@testable import checklists
import XCTest

/// Exercises `MixpanelAnalyticsClient`'s lazy-init contract against the **real class**, not a
/// simulation — see core-docs/analytics-spec.md §13 contract 9 and §7.2.
///
/// **Every test here is restricted to paths that never call `Mixpanel.initialize`.** An earlier
/// version of this file called `track`/`identify` directly against the real class to prove the
/// SDK becomes initialized — but `MixpanelInstance.reset()`'s first statement is `flush()`, which
/// POSTs the queue over the network. Even with a fake token, that leaves real artifacts behind
/// (`*_MPDB.sqlite`, `Mixpanel.plist` in the simulator's `Library`) that persist across runs and
/// get re-sent on the next one — and it writes through to the real `UserDefaults`, defeating test
/// isolation. So this file asserts only the **negative** half of the contract: a client that has
/// never been told to track something never touches the network, however it is called. The
/// **positive** half — that an opted-in `track` actually initializes the SDK exactly once — is not
/// safely assertable in a unit test against the real class, and is instead covered by the manual
/// simulator verification in analytics-spec.md §5.
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

  /// The regression guard that matters most: `reset()` must never itself be a path to
  /// `ensureInitialized()`. If it ever became one, an opted-out `ConsentGatedAnalyticsClient`
  /// calling the always-passed-through `reset()` (§7.2) would silently open a connection.
  @MainActor
  func testResetOnNeverInitializedClientLeavesItUninitialized() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    client.reset()
    XCTAssertFalse(client.isSDKInitializedForTesting)
  }

  @MainActor
  func testRefreshSuperPropertiesIsANoOpBeforeInitialization() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    client.refreshSuperProperties()
    XCTAssertFalse(client.isSDKInitializedForTesting)
  }

  @MainActor
  func testRefreshCohortPeoplePropertiesIsANoOpBeforeInitialization() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    client.refreshCohortPeopleProperties(checklistsCount: 3)
    XCTAssertFalse(client.isSDKInitializedForTesting)
  }

  @MainActor
  func testSetAnalyticsOptInAtIsANoOpBeforeInitialization() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    client.setAnalyticsOptInAt()
    XCTAssertFalse(client.isSDKInitializedForTesting)
  }

  /// States the privacy contract directly: `ConsentGatedAnalyticsClient` wrapping a **real**
  /// `MixpanelAnalyticsClient` with an opted-out closure must leave the SDK uninitialized no
  /// matter how many `track`/`identify` calls arrive — none of them may reach
  /// `ensureInitialized()`. Safe to run: an opted-out gate suppresses every call before it
  /// reaches the wrapped client, so `Mixpanel.initialize` is never invoked here either. Without
  /// this test, adding an `ensureInitialized()` call to `reset()` or a people-property setter
  /// would break the guarantee with an otherwise-green suite.
  @MainActor
  func testGatedClientNeverInitializesMixpanelWhenOptedOut() {
    let mixpanelClient = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    let gated = ConsentGatedAnalyticsClient(wrapping: mixpanelClient, isOptedIn: { false })

    gated.track(AnalyticsEvent.appOpened, properties: nil)
    gated.track(AnalyticsEvent.checklistsViewed, properties: nil)
    gated.identify("some-distinct-id")
    gated.refreshSuperProperties()
    gated.refreshCohortPeopleProperties(checklistsCount: 5)
    gated.setAnalyticsOptInAt()

    XCTAssertFalse(mixpanelClient.isSDKInitializedForTesting)
  }
}
