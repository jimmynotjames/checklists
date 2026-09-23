//
//  SyncStatusTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import Testing

/// Covers `SyncStatus.rowState`'s derivation from `(containerBacking, accountStatus)` and the
/// `record(_:)` reducer. No container needed — `SyncStatus` is constructed directly and its
/// properties mutated.
@Suite("SyncStatus")
struct SyncStatusTests {
  @Test("checking account status yields .checking regardless of backing", arguments: [
    ContainerBacking.cloudKit, .localFallback,
  ])
  func rowStateChecking(backing: ContainerBacking) {
    let syncStatus = SyncStatus(containerBacking: backing, accountStatus: .checking)
    #expect(syncStatus.rowState == .checking)
  }

  @Test("available on a CloudKit container yields .available")
  func rowStateAvailable() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    #expect(syncStatus.rowState == .available)
  }

  @Test("local fallback with an available account yields .paused")
  func rowStatePausedWhenLocalFallbackAndAvailable() {
    let syncStatus = SyncStatus(containerBacking: .localFallback, accountStatus: .available)
    #expect(syncStatus.rowState == .paused)
  }

  /// Every non-available account status collapses onto the existing `.unavailable` row in PR 1 —
  /// the new cases don't get their own row until PR 2's copy lands.
  @Test("every non-available account status yields .unavailable, on either backing", arguments: [
    SyncStatus.AccountStatus.noAccount, .restricted, .temporarilyUnavailable, .couldNotDetermine,
  ], [ContainerBacking.cloudKit, .localFallback])
  func rowStateUnavailableForNonAvailableAccountStatus(
    accountStatus: SyncStatus.AccountStatus,
    backing: ContainerBacking
  ) {
    let syncStatus = SyncStatus(containerBacking: backing, accountStatus: accountStatus)
    #expect(syncStatus.rowState == .unavailable)
  }

  // MARK: - record(_:)

  @Test("a successful event records its end date and clears its own prior failure")
  func recordSuccessClearsOwnFailure() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit)
    let failure = SyncErrorCode(domain: "CKErrorDomain", code: 4)
    syncStatus.record(SyncEventSnapshot(operation: .export, endDate: .now, error: failure))
    #expect(syncStatus.syncActivity[.export]?.latestFailure == failure)

    let successDate = Date(timeIntervalSince1970: 1000)
    syncStatus.record(SyncEventSnapshot(operation: .export, endDate: successDate, error: nil))

    let state = syncStatus.syncActivity[.export]
    #expect(state?.lastSuccess == successDate)
    #expect(state?.latestFailure == nil)
  }

  @Test("a failure records its error without disturbing the prior success")
  func recordFailureKeepsPriorSuccess() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit)
    let successDate = Date(timeIntervalSince1970: 1000)
    syncStatus.record(SyncEventSnapshot(operation: .setup, endDate: successDate, error: nil))

    let failure = SyncErrorCode(domain: "CKErrorDomain", code: 25)
    syncStatus.record(SyncEventSnapshot(operation: .setup, endDate: .now, error: failure))

    let state = syncStatus.syncActivity[.setup]
    #expect(state?.lastSuccess == successDate)
    #expect(state?.latestFailure == failure)
  }

  @Test("a failure on one operation does not touch another operation's state")
  func recordFailureIsScopedToItsOwnOperation() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit)
    let successDate = Date(timeIntervalSince1970: 1000)
    syncStatus.record(SyncEventSnapshot(operation: .import, endDate: successDate, error: nil))

    syncStatus.record(SyncEventSnapshot(
      operation: .export,
      endDate: .now,
      error: SyncErrorCode(domain: "CKErrorDomain", code: 25)
    ))

    #expect(syncStatus.syncActivity[.import]?.lastSuccess == successDate)
    #expect(syncStatus.syncActivity[.import]?.latestFailure == nil)
  }
}
