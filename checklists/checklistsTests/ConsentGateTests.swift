//
//  ConsentGateTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import Testing

/// Covers `ConsentGatedAnalyticsClient` — the seam that makes the consent flag actually gate
/// something (core-docs/analytics-spec.md §2, canonical constraint #3). Without it,
/// `analyticsOptIn` is read only by the Settings toggle's own getter and the consent controller's
/// writes: an opted-out install still emits every event, including `checklist_viewed` carrying
/// `checklist_name` — the one thing the consent sheet exists to gate.
@Suite("Consent-gated analytics client")
struct ConsentGateTests {
  @Test("opting out suppresses every method except reset")
  func optedOutSuppressesEveryMethodExceptReset() {
    let spy = SpyAnalyticsClient()
    let gate = ConsentGatedAnalyticsClient(wrapping: spy, isOptedIn: { false })

    gate.track(AnalyticsEvent.appOpened, properties: nil)
    gate.identify("some-id")
    gate.refreshSuperProperties()
    gate.refreshCohortPeopleProperties(checklistsCount: 3)
    gate.setAnalyticsOptInAt()
    gate.setRatingPromptFirstEligibleAt(Self.stamp)
    gate.setRatingPromptLastRequestedAt(Self.stamp)

    #expect(
      spy.calls.isEmpty,
      "An opted-out install must never reach the wrapped client through any of these."
    )
  }

  private static let stamp = Date(timeIntervalSinceReferenceDate: 600_000_000)

  @Test("opting in allows every method through")
  func optedInAllowsEveryMethodThrough() {
    let spy = SpyAnalyticsClient()
    let gate = ConsentGatedAnalyticsClient(wrapping: spy, isOptedIn: { true })

    gate.track(AnalyticsEvent.appOpened, properties: nil)
    gate.identify("some-id")
    gate.refreshSuperProperties()
    gate.refreshCohortPeopleProperties(checklistsCount: 3)
    gate.setAnalyticsOptInAt()
    gate.setRatingPromptFirstEligibleAt(Self.stamp)
    gate.setRatingPromptLastRequestedAt(Self.stamp)

    #expect(
      spy.calls ==
        [
          .track(AnalyticsEvent.appOpened, nil),
          .identify("some-id"),
          .refreshSuperProperties,
          .refreshCohort(3),
          .setAnalyticsOptInAt,
          .setRatingPromptFirstEligibleAt(Self.stamp),
          .setRatingPromptLastRequestedAt(Self.stamp),
        ]
    )
  }

  /// `reset()` must always pass through, even while opted out: the controller calls it *during*
  /// the opt-out transition, before the flag has flipped, so gating it would silently no-op the
  /// one reset that matters.
  @Test("reset always passes through even while opted out")
  func resetAlwaysPassesThroughEvenWhileOptedOut() {
    let spy = SpyAnalyticsClient()
    let gate = ConsentGatedAnalyticsClient(wrapping: spy, isOptedIn: { false })

    gate.reset()

    #expect(spy.calls == [.reset])
  }

  /// The gate re-reads `isOptedIn` on every call rather than capturing its answer once — proven
  /// by flipping the closure's answer mid-test, on the same gate instance, and observing the
  /// behaviour change without reconstructing it.
  @Test("the gate re-reads the isOptedIn closure on every call")
  func gateReReadsTheClosureOnEveryCall() {
    let spy = SpyAnalyticsClient()
    var optedIn = false
    let gate = ConsentGatedAnalyticsClient(wrapping: spy, isOptedIn: { optedIn })

    gate.track(AnalyticsEvent.appOpened, properties: nil)
    #expect(spy.calls.isEmpty, "Should still be suppressed while opted out.")

    optedIn = true
    gate.track(AnalyticsEvent.appOpened, properties: nil)
    #expect(
      spy.calls == [.track(AnalyticsEvent.appOpened, nil)],
      "Flipping the closure's answer must change behaviour without reconstructing the gate."
    )

    optedIn = false
    gate.track(AnalyticsEvent.appOpened, properties: nil)
    #expect(
      spy.calls == [.track(AnalyticsEvent.appOpened, nil)],
      "Flipping back to opted-out must suppress again, proving the answer isn't cached from the first read."
    )
  }
}
