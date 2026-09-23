//
//  PersistenceAnalyticsTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing

/// Covers the analytics emitted by the three call sites that run before any SwiftUI environment
/// exists (analytics-spec.md §Non-SwiftUI callers).
@Suite("Persistence and startup analytics")
struct PersistenceAnalyticsTests {
  /// Both store paths failing is the only way the app cannot open a store at all. The fatal-error
  /// event still fires once, from the local fallback's catch — the CloudKit branch failing first
  /// reports its own `cloudkit_container_fell_back` on the way through, since that is a real,
  /// separate sync-health signal even when the local store then fails too.
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
    #expect(spy.trackedEventNames == [AnalyticsEvent.cloudkitContainerFellBack, AnalyticsEvent.persistenceFatalError])
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

  /// The CloudKit branch failing and falling through to a working local store is not a fatal
  /// error, but it is a sync-health signal — `cloudkit_container_fell_back` carries it.
  @Test("a CloudKit fallback reports the fell-back event with the CloudKit error's properties")
  func cloudKitFallbackReportsFellBackEvent() throws {
    let spy = SpyAnalyticsClient()
    let stubContainer = try TestModelContainer.make()
    let cloudFailure = NSError(domain: "CKErrorDomain", code: 9)

    let result = try ProductionContainerFactory.make(
      cloud: { _ in throw cloudFailure },
      local: { _ in stubContainer },
      analytics: spy
    )

    #expect(result.backing == .localFallback)
    #expect(result.fallbackError == SyncErrorCode(domain: "CKErrorDomain", code: 9))
    #expect(spy.trackedEventNames == [AnalyticsEvent.cloudkitContainerFellBack])
    #expect(spy.rawProperty(AnalyticsProperty.errorDomain, forFirst: AnalyticsEvent.cloudkitContainerFellBack, as: String.self) == "CKErrorDomain")
    #expect(spy.rawProperty(AnalyticsProperty.errorCode, forFirst: AnalyticsEvent.cloudkitContainerFellBack, as: Int.self) == 9)
  }

  @Test("a successful CloudKit open reports no fallback error and no fell-back event")
  func successfulCloudKitOpenReportsNoFallback() throws {
    let spy = SpyAnalyticsClient()
    let stubContainer = try TestModelContainer.make()

    let result = try ProductionContainerFactory.make(
      cloud: { _ in stubContainer },
      local: { _ in stubContainer },
      analytics: spy
    )

    #expect(result.fallbackError == nil)
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
    let stage = spy.rawProperty(
      AnalyticsProperty.startupStage,
      forFirst: AnalyticsEvent.startupFailed,
      as: String.self
    )
    #expect(stage == ContainerCreationFailure.Stage.storeOpen.rawValue)
  }

  /// The `persistence_fatal_error` twin of this assertion is above; `startup_failed` carries the
  /// same risk and needs the same exact-key-set pin, for the same reason: a regression that
  /// reinstated the error's `description` would leak the first characters of the user's own string
  /// and still pass a substring check.
  @Test("a failed startup sends exactly the structured keys and nothing else")
  func failedStartupSendsOnlyStructuredKeys() {
    let spy = SpyAnalyticsClient()
    let coordinator = AppStartupCoordinator(
      makeContainer: {
        throw NSError(
          domain: "NSCocoaErrorDomain",
          code: 134_060,
          userInfo: [NSLocalizedFailureReasonErrorKey: "a-checklist-item-the-user-typed"]
        )
      },
      analytics: spy
    )

    _ = coordinator.run()

    let sent = spy.properties(forFirst: AnalyticsEvent.startupFailed)
    #expect(sent != nil, "The event must carry properties.")
    #expect(Set(sent?.keys ?? [:].keys) == [
      AnalyticsProperty.errorDomain,
      AnalyticsProperty.errorCode,
      AnalyticsProperty.startupStage,
    ])
  }

  /// The stages after the store opens are skipped on an automated launch, so they are reached here
  /// through the coordinator's own seams. Without this, nothing proves a later stage is tagged as
  /// itself rather than as `storeOpen`.
  @Test("each startup stage is tagged as itself", arguments: [
    (ContainerCreationFailure.Stage.legacyImport, true),
    (ContainerCreationFailure.Stage.firstLaunchSeed, false),
  ])
  func eachStageIsTaggedAsItself(stage: ContainerCreationFailure.Stage, failsOnImport: Bool) throws {
    let spy = SpyAnalyticsClient()
    let stubContainer = try TestModelContainer.make()
    let thrown = NSError(domain: "TestDomain", code: 7)
    let coordinator = AppStartupCoordinator(
      makeContainer: { ContainerLaunchResult(container: stubContainer, backing: .localFallback, fallbackError: nil) },
      importLegacyData: { _ in if failsOnImport { throw thrown } },
      seedFirstLaunchData: { _ in if !failsOnImport { throw thrown } },
      runsPostOpenStages: true,
      analytics: spy
    )

    guard case let .failed(failure) = coordinator.run() else {
      Issue.record("Expected the coordinator to report failure.")
      return
    }

    #expect(failure.stage == stage)
    #expect(failure.errorDomain == "TestDomain")
    #expect(failure.errorCode == 7)
    #expect(!failure.allowsStoreReset, "The store opened, so there is nothing safe to reset.")
    let sent = spy.rawProperty(
      AnalyticsProperty.startupStage,
      forFirst: AnalyticsEvent.startupFailed,
      as: String.self
    )
    #expect(sent == stage.rawValue)
  }

  /// A seed failure arrives as a `PersistenceError`, which already carries a `PersistenceOperation`.
  /// The stage must come from the `try` that threw, not from that operation — they answer different
  /// questions, and the import can throw errors carrying no operation at all.
  @Test("the stage is not read off a PersistenceError's operation")
  func stageIsNotInferredFromPersistenceOperation() throws {
    let stubContainer = try TestModelContainer.make()
    let coordinator = AppStartupCoordinator(
      makeContainer: { ContainerLaunchResult(container: stubContainer, backing: .localFallback, fallbackError: nil) },
      // Injected even though it cannot fail here: the default would run the real importer against
      // `UserDefaults.standard` and the host's Realm path.
      importLegacyData: { _ in },
      seedFirstLaunchData: { _ in
        throw PersistenceError(operation: .sampleSeed, errorDomain: "NSCocoaErrorDomain", errorCode: 134_030)
      },
      runsPostOpenStages: true,
      analytics: SpyAnalyticsClient()
    )

    guard case let .failed(failure) = coordinator.run() else {
      Issue.record("Expected the coordinator to report failure.")
      return
    }

    #expect(failure.stage == .firstLaunchSeed)
    // Unwrapped from the `PersistenceError` rather than bridged, so the real domain and code
    // survive instead of collapsing into `checklists.PersistenceError 1`.
    #expect(failure.errorDomain == "NSCocoaErrorDomain")
    #expect(failure.errorCode == 134_030)
  }

  /// `startup_failed` is the measure of how often someone is shown the failure screen instead of
  /// their checklists, so it must not fire on a launch that succeeded.
  @Test("a successful startup emits no analytics")
  func successfulStartupEmitsNoAnalytics() throws {
    let spy = SpyAnalyticsClient()
    let stubContainer = try TestModelContainer.make()
    let coordinator = AppStartupCoordinator(
      makeContainer: { ContainerLaunchResult(container: stubContainer, backing: .localFallback, fallbackError: nil) },
      analytics: spy
    )

    guard case .ready = coordinator.run() else {
      Issue.record("Expected the coordinator to report readiness.")
      return
    }

    #expect(spy.calls.isEmpty)
  }
}
