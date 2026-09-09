//
//  PersistenceAnalyticsTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import XCTest

/// Covers the analytics emitted by the three call sites that run before any SwiftUI environment
/// exists (analytics-spec.md §7.3).
///
/// These were untestable while they reached a static facade directly. Each now takes the client
/// as a parameter defaulting to `AppAnalytics.shared`, which is what lets a spy be passed in here
/// without changing how the app wires them.
///
/// See the note on `AnalyticsTextTests` for the `nonisolated` class / `@MainActor` method pattern.
nonisolated final class PersistenceAnalyticsTests: XCTestCase {
  /// Both store paths failing is the only way the app cannot open a store at all — the event
  /// fires once, from the local fallback's catch, not once per attempted path.
  @MainActor func testUnopenableStoreReportsFatalErrorOnce() {
    let spy = SpyAnalyticsClient()
    let failure = NSError(domain: "NSCocoaErrorDomain", code: 134_060)

    XCTAssertThrowsError(
      try ProductionContainerFactory.make(
        cloud: { _ in throw failure },
        local: { _ in throw failure },
        analytics: spy
      )
    )

    XCTAssertEqual(spy.count(of: AnalyticsEvent.persistenceFatalError), 1)
    XCTAssertEqual(spy.trackedEventNames, [AnalyticsEvent.persistenceFatalError])
  }

  @MainActor func testFatalErrorCarriesATruncatedErrorProperty() {
    let spy = SpyAnalyticsClient()
    let failure = NSError(
      domain: String(repeating: "D", count: 400),
      code: 1
    )

    XCTAssertThrowsError(
      try ProductionContainerFactory.make(
        cloud: { _ in throw failure },
        local: { _ in throw failure },
        analytics: spy
      )
    )

    // Asserted against the *raw* value, not its description: the backend drops a property whose
    // type it cannot represent, silently, so the type is part of the contract.
    let message = spy.rawProperty(
      AnalyticsProperty.error,
      forFirst: AnalyticsEvent.persistenceFatalError,
      as: String.self
    )
    XCTAssertNotNil(message, "The error property must arrive as a String.")
    XCTAssertEqual(message?.count, AnalyticsText.maximumLength)
  }

  /// A store that opens fine must emit nothing — the error events are not launch telemetry.
  @MainActor func testSuccessfulStoreEmitsNoAnalytics() throws {
    let spy = SpyAnalyticsClient()
    let stubContainer = try TestModelContainer.make()

    _ = try ProductionContainerFactory.make(
      cloud: { _ in stubContainer },
      local: { _ in stubContainer },
      analytics: spy
    )

    XCTAssertTrue(spy.calls.isEmpty)
  }

  // MARK: - Startup coordinator

  @MainActor func testFailedStartupReportsStartupFailed() {
    let spy = SpyAnalyticsClient()
    let coordinator = AppStartupCoordinator(
      makeContainer: { throw NSError(domain: "NSCocoaErrorDomain", code: 134_060) },
      analytics: spy
    )

    guard case .failed = coordinator.run() else {
      return XCTFail("Expected the coordinator to report failure.")
    }

    XCTAssertEqual(spy.trackedEventNames, [AnalyticsEvent.startupFailed])
    XCTAssertNotNil(spy.properties(forFirst: AnalyticsEvent.startupFailed)?[AnalyticsProperty.error])
  }

  /// `startup_failed` is the measure of how often someone is shown the failure screen instead of
  /// their checklists, so it must not fire on a launch that succeeded.
  @MainActor func testSuccessfulStartupEmitsNoAnalytics() throws {
    let spy = SpyAnalyticsClient()
    let stubContainer = try TestModelContainer.make()
    let coordinator = AppStartupCoordinator(
      makeContainer: { (container: stubContainer, backing: .localFallback) },
      analytics: spy
    )

    guard case .ready = coordinator.run() else {
      return XCTFail("Expected the coordinator to report readiness.")
    }

    XCTAssertTrue(spy.calls.isEmpty)
  }
}
