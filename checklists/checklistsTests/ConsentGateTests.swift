//
//  ConsentGateTests.swift
//  checklistsTests
//

@testable import checklists
import XCTest

/// Covers `ConsentGatedAnalyticsClient` — the seam that makes the consent flag actually gate
/// something (core-docs/analytics-spec.md §2, canonical constraint #3). Without it,
/// `analyticsOptIn` is read only by the Settings toggle's own getter and the consent controller's
/// writes: an opted-out install still emits every event, including `checklist_viewed` carrying
/// `checklist_name` — the one thing the consent sheet exists to gate.
///
/// See the note on `AnalyticsTextTests` for the `nonisolated` class / `@MainActor` method
/// pattern.
nonisolated final class ConsentGateTests: XCTestCase {
  @MainActor func testOptedOutSuppressesEveryMethodExceptReset() {
    let spy = SpyAnalyticsClient()
    let gate = ConsentGatedAnalyticsClient(wrapping: spy, isOptedIn: { false })

    gate.track(AnalyticsEvent.appOpened, properties: nil)
    gate.identify("some-id")
    gate.refreshSuperProperties()
    gate.refreshCohortPeopleProperties(checklistsCount: 3)
    gate.setAnalyticsOptInAt()

    XCTAssertTrue(
      spy.calls.isEmpty,
      "An opted-out install must never reach the wrapped client through any of these."
    )
  }

  @MainActor func testOptedInAllowsEveryMethodThrough() {
    let spy = SpyAnalyticsClient()
    let gate = ConsentGatedAnalyticsClient(wrapping: spy, isOptedIn: { true })

    gate.track(AnalyticsEvent.appOpened, properties: nil)
    gate.identify("some-id")
    gate.refreshSuperProperties()
    gate.refreshCohortPeopleProperties(checklistsCount: 3)
    gate.setAnalyticsOptInAt()

    XCTAssertEqual(
      spy.calls,
      [
        .track(AnalyticsEvent.appOpened, nil),
        .identify("some-id"),
        .refreshSuperProperties,
        .refreshCohort(3),
        .setAnalyticsOptInAt,
      ]
    )
  }

  /// `reset()` must always pass through, even while opted out: the controller calls it *during*
  /// the opt-out transition, before the flag has flipped, so gating it would silently no-op the
  /// one reset that matters.
  @MainActor func testResetAlwaysPassesThroughEvenWhileOptedOut() {
    let spy = SpyAnalyticsClient()
    let gate = ConsentGatedAnalyticsClient(wrapping: spy, isOptedIn: { false })

    gate.reset()

    XCTAssertEqual(spy.calls, [.reset])
  }

  /// The gate re-reads `isOptedIn` on every call rather than capturing its answer once — proven
  /// by flipping the closure's answer mid-test, on the same gate instance, and observing the
  /// behaviour change without reconstructing it.
  @MainActor func testGateReReadsTheClosureOnEveryCall() {
    let spy = SpyAnalyticsClient()
    var optedIn = false
    let gate = ConsentGatedAnalyticsClient(wrapping: spy, isOptedIn: { optedIn })

    gate.track(AnalyticsEvent.appOpened, properties: nil)
    XCTAssertTrue(spy.calls.isEmpty, "Should still be suppressed while opted out.")

    optedIn = true
    gate.track(AnalyticsEvent.appOpened, properties: nil)
    XCTAssertEqual(
      spy.calls,
      [.track(AnalyticsEvent.appOpened, nil)],
      "Flipping the closure's answer must change behaviour without reconstructing the gate."
    )

    optedIn = false
    gate.track(AnalyticsEvent.appOpened, properties: nil)
    XCTAssertEqual(
      spy.calls,
      [.track(AnalyticsEvent.appOpened, nil)],
      "Flipping back to opted-out must suppress again, proving the answer isn't cached from the first read."
    )
  }
}
