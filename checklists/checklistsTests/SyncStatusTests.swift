//
//  SyncStatusTests.swift
//  checklistsTests
//

@testable import checklists
import CloudKit
import Foundation
import Testing

/// Covers `SyncStatus.rowState`'s precedence over `(containerBacking, accountStatus, syncActivity)`,
/// `rowPresentation`, and the `record(_:)` reducer. No container needed — `SyncStatus` is
/// constructed directly and its properties mutated.
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

  /// The row per account status, on either backing — an account problem outranks `.paused`.
  @Test("account status maps to its own row, on either backing", arguments: [
    (SyncStatus.AccountStatus.noAccount, SyncStatus.RowState.unavailable),
    (.restricted, .restricted),
    (.temporarilyUnavailable, .needsAttention),
    (.couldNotDetermine, .couldNotCheck),
  ], [ContainerBacking.cloudKit, .localFallback])
  func rowStateForAccountStatus(
    pair: (accountStatus: SyncStatus.AccountStatus, expected: SyncStatus.RowState),
    backing: ContainerBacking,
  ) {
    let syncStatus = SyncStatus(containerBacking: backing, accountStatus: pair.accountStatus)
    #expect(syncStatus.rowState == pair.expected)
  }

  // MARK: - rowState: sync failures

  @Test("CKError.quotaExceeded on a CloudKit-backed, signed-in launch yields .storageFull")
  func rowStateStorageFull() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    syncStatus.record(SyncEventSnapshot(
      operation: .export,
      endDate: .now,
      error: SyncErrorCode(domain: CKErrorDomain, code: CKError.Code.quotaExceeded.rawValue),
    ))
    #expect(syncStatus.rowState == .storageFull)
  }

  @Test("a non-transient sync failure yields .syncInterrupted")
  func rowStateSyncInterrupted() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    syncStatus.record(SyncEventSnapshot(
      operation: .setup,
      endDate: .now,
      error: SyncErrorCode(domain: CKErrorDomain, code: CKError.Code.internalError.rawValue),
    ))
    #expect(syncStatus.rowState == .syncInterrupted)
  }

  @Test(
    "transient network failures never change the row",
    arguments: [
      CKError.Code.networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy,
    ],
  )
  func rowStateIgnoresTransientFailures(code: CKError.Code) {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    syncStatus.record(SyncEventSnapshot(
      operation: .import,
      endDate: .now,
      error: SyncErrorCode(domain: CKErrorDomain, code: code.rawValue),
    ))
    #expect(syncStatus.rowState == .available)
  }

  @Test("a storage failure wins over a plain sync-interrupted failure on another operation")
  func rowStateStorageFullWinsOverSyncInterrupted() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    syncStatus.record(SyncEventSnapshot(
      operation: .import,
      endDate: .now,
      error: SyncErrorCode(domain: CKErrorDomain, code: CKError.Code.internalError.rawValue),
    ))
    syncStatus.record(SyncEventSnapshot(
      operation: .export,
      endDate: .now,
      error: SyncErrorCode(domain: CKErrorDomain, code: CKError.Code.quotaExceeded.rawValue),
    ))
    #expect(syncStatus.rowState == .storageFull)
  }

  @Test("paused wins over a sync failure recorded on a local-fallback launch")
  func rowStatePausedWinsOverSyncFailure() {
    let syncStatus = SyncStatus(containerBacking: .localFallback, accountStatus: .available)
    syncStatus.record(SyncEventSnapshot(
      operation: .export,
      endDate: .now,
      error: SyncErrorCode(domain: CKErrorDomain, code: CKError.Code.internalError.rawValue),
    ))
    #expect(syncStatus.rowState == .paused)
  }

  // MARK: - rowPresentation

  @Test("every row state has a non-empty title", arguments: SyncStatus.RowState.allCases)
  func presentationHasNonEmptyTitle(state: SyncStatus.RowState) {
    let syncStatus = SyncStatus(containerBacking: .cloudKit)
    #expect(!syncStatus.presentation(for: state).title.isEmpty)
  }

  @Test(
    "every row state makes a deliberate footer decision with no recorded sync activity",
    arguments: [
      (SyncStatus.RowState.checking, false),
      (.available, false),
      (.unavailable, true),
      (.paused, true),
      (.restricted, true),
      (.needsAttention, true),
      (.couldNotCheck, true),
      (.storageFull, true),
      (.syncInterrupted, true),
    ],
  )
  func presentationFooterDecision(pair: (state: SyncStatus.RowState, hasFooter: Bool)) {
    let syncStatus = SyncStatus(containerBacking: .cloudKit)
    #expect((syncStatus.presentation(for: pair.state).footer != nil) == pair.hasFooter)
  }

  @Test("the Active footer names the most recent sync success across operations")
  func presentationActiveFooterUsesMostRecentSuccess() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    syncStatus.record(SyncEventSnapshot(operation: .setup, endDate: Date(timeIntervalSince1970: 1000), error: nil))
    syncStatus.record(SyncEventSnapshot(operation: .export, endDate: Date(timeIntervalSince1970: 2000), error: nil))
    #expect(syncStatus.rowPresentation.footer != nil)
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
      error: SyncErrorCode(domain: "CKErrorDomain", code: 25),
    ))

    #expect(syncStatus.syncActivity[.import]?.lastSuccess == successDate)
    #expect(syncStatus.syncActivity[.import]?.latestFailure == nil)
  }
}
