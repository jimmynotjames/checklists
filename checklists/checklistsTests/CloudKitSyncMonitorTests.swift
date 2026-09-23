//
//  CloudKitSyncMonitorTests.swift
//  checklistsTests
//

@testable import checklists
import CloudKit
import CoreData
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
}
