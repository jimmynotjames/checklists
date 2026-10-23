//
//  CloudKitSyncMonitorTests.swift
//  checklistsTests
//

@testable import checklists
import CloudKit
import CoreData
import Foundation
import Testing

/// Covers the pure pieces of `CloudKitSyncMonitor`: error unwrapping and the `SyncOperation`
/// mapping. The real `NSPersistentCloudKitContainer.Event` can't be constructed in a test, which is
/// exactly why both live behind seams that take a plain error or event type.
@Suite("CloudKitSyncMonitor error unwrapping")
struct CloudKitSyncMonitorTests {
  @Test("a plain NSError is used as-is")
  func plainErrorUsedAsIs() {
    let error = NSError(domain: "NSCocoaErrorDomain", code: 4)
    let code = SyncErrorCode(unwrapping: error)
    #expect(code == SyncErrorCode(domain: "NSCocoaErrorDomain", code: 4))
  }

  @Test("a CKError that is not a partial failure is used as-is")
  func nonPartialCKErrorUsedAsIs() {
    let error = CKError(.networkUnavailable)
    let code = SyncErrorCode(unwrapping: error)
    #expect(code.domain == CKError.errorDomain)
    #expect(code.code == CKError.Code.networkUnavailable.rawValue)
  }

  @Test("a partial failure unwraps to its first underlying error")
  func partialFailureUnwrapsToFirstUnderlyingError() {
    let underlying = NSError(domain: "CKErrorDomain", code: CKError.Code.zoneNotFound.rawValue)
    let partial = CKError(.partialFailure, userInfo: [
      CKPartialErrorsByItemIDKey: ["item-1": underlying],
    ])

    let code = SyncErrorCode(unwrapping: partial)

    #expect(code == SyncErrorCode(domain: "CKErrorDomain", code: CKError.Code.zoneNotFound.rawValue))
  }

  @Test("a partial failure with no underlying errors falls back to itself")
  func partialFailureWithNoUnderlyingErrorsFallsBackToItself() {
    let partial = CKError(.partialFailure)
    let code = SyncErrorCode(unwrapping: partial)
    #expect(code.domain == CKError.errorDomain)
    #expect(code.code == CKError.Code.partialFailure.rawValue)
  }

  @Test("every known event type maps to its own SyncOperation", arguments: [
    (NSPersistentCloudKitContainer.EventType.setup, SyncOperation.setup),
    (.import, .import),
    (.export, .export),
  ])
  func eventTypeMapsToOperation(eventType: NSPersistentCloudKitContainer.EventType, expected: SyncOperation) {
    #expect(SyncOperation(eventType) == expected)
  }

  // MARK: - handle(_:)

  /// The real `NSPersistentCloudKitContainer.Event` can't be constructed, so `handle(_:)` is
  /// driven directly with a `SyncEventSnapshot` — the same seam `SyncStatus.record(_:)` uses.
  @Test("a failure records itself on syncStatus and fires cloudkit_sync_failed")
  func failureRecordsAndTracks() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit)
    let spy = SpyAnalyticsClient()
    let monitor = CloudKitSyncMonitor(syncStatus: syncStatus, analytics: spy)

    monitor.handle(SyncEventSnapshot(
      operation: .export,
      endDate: .now,
      error: SyncErrorCode(domain: "CKErrorDomain", code: 25),
    ))

    #expect(syncStatus.syncActivity[.export]?.latestFailure == SyncErrorCode(domain: "CKErrorDomain", code: 25))
    #expect(spy.trackedEventNames == [AnalyticsEvent.cloudkitSyncFailed])
    #expect(spy.rawProperty(AnalyticsProperty.syncOperation, forFirst: AnalyticsEvent.cloudkitSyncFailed, as: String.self) == "export")
    #expect(spy.rawProperty(AnalyticsProperty.errorDomain, forFirst: AnalyticsEvent.cloudkitSyncFailed, as: String.self) == "CKErrorDomain")
    #expect(spy.rawProperty(AnalyticsProperty.errorCode, forFirst: AnalyticsEvent.cloudkitSyncFailed, as: Int.self) == 25)
  }

  @Test("a success records itself and fires no analytics")
  func successRecordsAndTracksNothing() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit)
    let spy = SpyAnalyticsClient()
    let monitor = CloudKitSyncMonitor(syncStatus: syncStatus, analytics: spy)

    let successDate = Date(timeIntervalSince1970: 1000)
    monitor.handle(SyncEventSnapshot(operation: .setup, endDate: successDate, error: nil))

    #expect(syncStatus.syncActivity[.setup]?.lastSuccess == successDate)
    #expect(spy.calls.isEmpty)
  }

  @Test("the same (operation, domain, code) failure is reported only once per launch")
  func sameFailureReportedOnce() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit)
    let spy = SpyAnalyticsClient()
    let monitor = CloudKitSyncMonitor(syncStatus: syncStatus, analytics: spy)
    let error = SyncErrorCode(domain: "CKErrorDomain", code: 25)

    monitor.handle(SyncEventSnapshot(operation: .export, endDate: .now, error: error))
    monitor.handle(SyncEventSnapshot(operation: .export, endDate: .now, error: error))

    #expect(spy.count(of: AnalyticsEvent.cloudkitSyncFailed) == 1)
  }

  @Test("the same operation failing with a different error reports again")
  func differentErrorOnSameOperationReportsAgain() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit)
    let spy = SpyAnalyticsClient()
    let monitor = CloudKitSyncMonitor(syncStatus: syncStatus, analytics: spy)

    monitor.handle(SyncEventSnapshot(
      operation: .export,
      endDate: .now,
      error: SyncErrorCode(domain: "CKErrorDomain", code: 25),
    ))
    monitor.handle(SyncEventSnapshot(
      operation: .export,
      endDate: .now,
      error: SyncErrorCode(domain: "CKErrorDomain", code: 2),
    ))

    #expect(spy.count(of: AnalyticsEvent.cloudkitSyncFailed) == 2)
  }
}
