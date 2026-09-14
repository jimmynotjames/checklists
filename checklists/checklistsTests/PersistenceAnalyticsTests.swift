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
  @Test("a fatal error never sends the error's userInfo")
  func fatalErrorOmitsUserInfo() {
    let spy = SpyAnalyticsClient()
    let secret = "a-checklist-item-the-user-typed"
    let failure = NSError(
      domain: "NSCocoaErrorDomain",
      code: 134_060,
      userInfo: [NSLocalizedFailureReasonErrorKey: secret]
    )

    #expect(throws: (any Error).self) {
      try ProductionContainerFactory.make(
        cloud: { _ in throw failure },
        local: { _ in throw failure },
        analytics: spy
      )
    }

    let sent = spy.properties(forFirst: AnalyticsEvent.persistenceFatalError) ?? [:]
    #expect(sent.values.allSatisfy { !$0.contains(secret) })
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
    let properties = spy.properties(forFirst: AnalyticsEvent.startupFailed)
    #expect(properties?[AnalyticsProperty.errorDomain] == "NSCocoaErrorDomain")
    #expect(properties?[AnalyticsProperty.errorCode] == "134060")
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
