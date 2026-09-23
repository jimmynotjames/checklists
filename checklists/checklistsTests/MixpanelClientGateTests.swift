//
//  MixpanelClientGateTests.swift
//  checklistsTests
//

@testable import checklists
import Testing

/// Exercises `MixpanelAnalyticsClient`'s lazy-init contract against the **real class**, not a
/// simulation — see core-docs/analytics-spec.md §Launch and consent ordering.
///
/// **Every test here is restricted to paths that never call `Mixpanel.initialize`.** Calling
/// `track`/`identify` directly against the real class would initialize the SDK and reach
/// `MixpanelInstance.reset()`'s `flush()`, which POSTs over the network and leaves real artifacts
/// (`*_MPDB.sqlite`, `Mixpanel.plist`) behind — so this file asserts only the **negative** half of
/// the contract. The **positive** half — that an opted-in `track` actually initializes the SDK
/// exactly once — isn't safely assertable here.
@Suite("MixpanelAnalyticsClient lazy-init gate")
struct MixpanelClientGateTests {
  /// Deliberately not shaped like a real token (32 lowercase hex) — that would trip gitleaks
  /// (analytics-spec.md §Build hygiene); shape validation is `MixpanelTokenSource`'s job, not this class's.
  private static let testToken = "unit-test-mixpanel-token-not-real"

  @Test("constructing the client does not initialize the SDK")
  func initLeavesSDKUninitialized() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    #expect(!client.isSDKInitializedForTesting)
  }

  /// The regression guard that matters most: `reset()` must never itself be a path to
  /// `ensureInitialized()`. If it ever became one, an opted-out `ConsentGatedAnalyticsClient`
  /// calling the always-passed-through `reset()` (analytics-spec.md §Launch and consent ordering)
  /// would silently open a connection.
  @Test("calling reset() on a never-initialized client leaves it uninitialized")
  func resetOnNeverInitializedClientLeavesItUninitialized() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    client.reset()
    #expect(!client.isSDKInitializedForTesting)
  }

  @Test("refreshSuperProperties() is a no-op before initialization")
  func refreshSuperPropertiesIsANoOpBeforeInitialization() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    client.refreshSuperProperties()
    #expect(!client.isSDKInitializedForTesting)
  }

  @Test("refreshCohortPeopleProperties() is a no-op before initialization")
  func refreshCohortPeoplePropertiesIsANoOpBeforeInitialization() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    client.refreshCohortPeopleProperties(checklistsCount: 3)
    #expect(!client.isSDKInitializedForTesting)
  }

  @Test("setAnalyticsOptInAt() is a no-op before initialization")
  func setAnalyticsOptInAtIsANoOpBeforeInitialization() {
    let client = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    client.setAnalyticsOptInAt()
    #expect(!client.isSDKInitializedForTesting)
  }

  /// States the privacy contract directly: `ConsentGatedAnalyticsClient` wrapping a **real**
  /// `MixpanelAnalyticsClient` with an opted-out closure must leave the SDK uninitialized no
  /// matter how many `track`/`identify` calls arrive — none of them may reach
  /// `ensureInitialized()`. Safe to run: an opted-out gate suppresses every call before it
  /// reaches the wrapped client, so `Mixpanel.initialize` is never invoked here either. Without
  /// this test, adding an `ensureInitialized()` call to `reset()` or a people-property setter
  /// would break the guarantee with an otherwise-green suite.
  @Test("an opted-out gated client never initializes the wrapped Mixpanel client")
  func gatedClientNeverInitializesMixpanelWhenOptedOut() {
    let mixpanelClient = MixpanelAnalyticsClient(token: Self.testToken, distinctIdProvider: { nil })
    let gated = ConsentGatedAnalyticsClient(wrapping: mixpanelClient, isOptedIn: { false })

    gated.track(AnalyticsEvent.appOpened, properties: nil)
    gated.track(AnalyticsEvent.checklistsViewed, properties: nil)
    gated.identify("some-distinct-id")
    gated.refreshSuperProperties()
    gated.refreshCohortPeopleProperties(checklistsCount: 5)
    gated.setAnalyticsOptInAt()

    #expect(!mixpanelClient.isSDKInitializedForTesting)
  }
}
