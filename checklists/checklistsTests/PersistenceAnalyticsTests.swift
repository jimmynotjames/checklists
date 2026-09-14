//
//  PersistenceAnalyticsTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing

/// Covers the analytics emitted by the three call sites that run before any SwiftUI environment
/// exists (analytics-spec.md §7.3).
///
/// These were untestable while they reached a static facade directly. Each now takes the client
/// as a parameter defaulting to `AppAnalytics.shared`, which is what lets a spy be passed in here
/// without changing how the app wires them.
@Suite("Persistence and startup analytics")
struct PersistenceAnalyticsTests {
  /// Both store paths failing is the only way the app cannot open a store at all — the event
  /// fires once, from the local fallback's catch, not once per attempted path.
  @Test("an unopenable store reports a fatal-error event exactly once")
  func unopenableStoreReportsFatalErrorOnce() {
    let spy = SpyAnalyticsClient()
    let failure = NSError(domain: "NSCocoaErrorDomain", code: 134_060)

    #expect(throws: (any Error).self) {
      try ProductionContainerFactory.make(
        cloud: { _ in throw failure },
        local: { _ in throw failure },
        analytics: spy
      )
    }

    #expect(spy.count(of: AnalyticsEvent.persistenceFatalError) == 1)
    #expect(spy.trackedEventNames == [AnalyticsEvent.persistenceFatalError])
  }

  @Test("a fatal error carries the error domain as a string and the code as an Int")
  func fatalErrorCarriesStructuredErrorProperties() {
    let spy = SpyAnalyticsClient()
    let failure = NSError(domain: "NSCocoaErrorDomain", code: 134_060)

    #expect(throws: (any Error).self) {
      try ProductionContainerFactory.make(
        cloud: { _ in throw failure },
        local: { _ in throw failure },
        analytics: spy
      )
    }

    // Asserted against the *raw* values, not their descriptions: the backend drops a property whose
    // type it cannot represent, silently, so the type is part of the contract. The code especially —
    // stringifying it would look like a pass while sending "134060" instead of 134060.
    let domain = spy.rawProperty(
      AnalyticsProperty.errorDomain,
      forFirst: AnalyticsEvent.persistenceFatalError,
      as: String.self
    )
    let code = spy.rawProperty(
      AnalyticsProperty.errorCode,
      forFirst: AnalyticsEvent.persistenceFatalError,
      as: Int.self
    )
    #expect(domain == "NSCocoaErrorDomain")
    #expect(code == 134_060)
  }

  /// `userInfo` can serialise the user's own content, which is why `ContainerCreationFailure` and
  /// the `OSLog` privacy annotations refuse it. The analytics payload must refuse it too.
  ///
  /// Asserted as an **exact key set**, not by scanning values for the secret. Scanning does not
  /// work: `userInfo` is the last field of `NSError.description`, so a regression that reinstated
  /// `AnalyticsText.truncated(error.description)` would send the first 18 characters of the user's
  /// string and still pass a substring check. The only durable assertion is that nothing beyond
  /// the two structured keys is sent at all.
  @Test("a fatal error sends exactly the structured error keys and nothing else")
  func fatalErrorSendsOnlyStructuredKeys() {
    let spy = SpyAnalyticsClient()
    let failure = NSError(
      domain: "NSCocoaErrorDomain",
      code: 134_060,
      userInfo: [NSLocalizedFailureReasonErrorKey: "a-checklist-item-the-user-typed"]
    )

    #expect(throws: (any Error).self) {
      try ProductionContainerFactory.make(
        cloud: { _ in throw failure },
        local: { _ in throw failure },
        analytics: spy
      )
    }

    let sent = spy.properties(forFirst: AnalyticsEvent.persistenceFatalError)
    #expect(sent != nil, "The event must carry properties.")
    #expect(Set(sent?.keys ?? [:].keys) == [
      AnalyticsProperty.errorDomain,
      AnalyticsProperty.errorCode,
    ])
  }

  /// A store that opens fine must emit nothing — the error events are not launch telemetry.
  @Test("a store that opens successfully emits no analytics")
  func successfulStoreEmitsNoAnalytics() throws {
    let spy = SpyAnalyticsClient()
    let stubContainer = try TestModelContainer.make()

    _ = try ProductionContainerFactory.make(
      cloud: { _ in stubContainer },
      local: { _ in stubContainer },
      analytics: spy
    )

    #expect(spy.calls.isEmpty)
  }

  // MARK: - Startup coordinator

  @Test("a failed startup reports the startup-failed event")
  func failedStartupReportsStartupFailed() {
    let spy = SpyAnalyticsClient()
    let coordinator = AppStartupCoordinator(
      makeContainer: { throw NSError(domain: "NSCocoaErrorDomain", code: 134_060) },
      analytics: spy
    )

    guard case .failed = coordinator.run() else {
      Issue.record("Expected the coordinator to report failure.")
      return
    }

    #expect(spy.trackedEventNames == [AnalyticsEvent.startupFailed])
    // Through `rawProperty`, not `properties(forFirst:)`: the latter stringifies, so it would pass
    // identically if the code were sent as "134060" — and a string where the backend expects a
    // number is silently dropped.
    let domain = spy.rawProperty(
      AnalyticsProperty.errorDomain,
      forFirst: AnalyticsEvent.startupFailed,
      as: String.self
    )
    let code = spy.rawProperty(
      AnalyticsProperty.errorCode,
      forFirst: AnalyticsEvent.startupFailed,
      as: Int.self
    )
    #expect(domain == "NSCocoaErrorDomain")
    #expect(code == 134_060)
  }

  /// `startup_failed` is the measure of how often someone is shown the failure screen instead of
  /// their checklists, so it must not fire on a launch that succeeded.
  @Test("a successful startup emits no analytics")
  func successfulStartupEmitsNoAnalytics() throws {
    let spy = SpyAnalyticsClient()
    let stubContainer = try TestModelContainer.make()
    let coordinator = AppStartupCoordinator(
      makeContainer: { (container: stubContainer, backing: .localFallback) },
      analytics: spy
    )

    guard case .ready = coordinator.run() else {
      Issue.record("Expected the coordinator to report readiness.")
      return
    }

    #expect(spy.calls.isEmpty)
  }
}
