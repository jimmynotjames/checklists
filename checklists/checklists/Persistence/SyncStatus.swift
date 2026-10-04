//
//  SyncStatus.swift
//  checklists
//

import CloudKit
import Foundation
import Observation

/// Combines this launch's `ContainerBacking` with the live iCloud account status and observed sync
/// activity into the Settings screen's iCloud row. `accountStatus` is written by the app-lifetime
/// check in `ChecklistsApp` via `ICloudStatusLoader`. Why the two signals stay apart:
/// persistence-design.md §Sync status.
@Observable
final class SyncStatus {
  /// Raw values are the `icloud_account` analytics vocabulary and the Feedback diagnostics text —
  /// `.checking` is never sent (`ICloudStatusLoader` fires `icloud_status_checked` only once the
  /// status leaves it).
  enum AccountStatus: String, CaseIterable {
    case checking
    case available
    case noAccount = "no_account"
    case restricted
    case temporarilyUnavailable = "temporarily_unavailable"
    case couldNotDetermine = "could_not_determine"
  }

  /// Settings' iCloud row. Why `.paused` exists, and the precedence among these:
  /// persistence-design.md §Sync status.
  enum RowState: CaseIterable {
    case checking
    case available
    /// No iCloud account signed in on this device.
    case unavailable
    /// Local-only container despite a potentially available iCloud account.
    case paused
    /// Signed in, but the account is restricted (e.g. Screen Time, an organization).
    case restricted
    /// Signed in, but the account needs the person's attention (Apple Account confirmation).
    case needsAttention
    /// The account status query failed or hasn't resolved (e.g. no network).
    case couldNotCheck
    /// A sync event failed with `CKError.quotaExceeded`.
    case storageFull
    /// A sync event failed with any other non-transient error.
    case syncInterrupted
  }

  let containerBacking: ContainerBacking

  var accountStatus: AccountStatus

  /// Set once, from the launch fallback: `ProductionContainerFactory.cloudKitEnabled` caught the
  /// CloudKit container's throw before falling back to the local store. `nil` on a launch that
  /// didn't fall back.
  let fallbackError: SyncErrorCode?

  /// Per-operation sync history, folded in by `CloudKitSyncMonitor.record(_:)`.
  var syncActivity: [SyncOperation: SyncOperationState] = [:]

  /// Guards `icloud_status_checked` firing exactly once per launch — an instance flag rather than a
  /// static, since the "load once" and "observe account changes" tasks in `ChecklistsApp` can both
  /// be in flight together.
  var hasReportedInitialAccountStatus = false

  /// Orders `ICloudStatusLoader` queries, which run concurrently: each load takes the next number,
  /// and publishes only if no later-started load has published already.
  var accountQueriesStarted = 0
  var newestPublishedAccountQuery = 0

  init(
    containerBacking: ContainerBacking,
    accountStatus: AccountStatus = .checking,
    fallbackError: SyncErrorCode? = nil
  ) {
    self.containerBacking = containerBacking
    self.accountStatus = accountStatus
    self.fallbackError = fallbackError
  }
}

extension SyncStatus {
  /// Precedence: checking → account problem → paused (local fallback) → sync failure → active. An
  /// account problem outranks `.paused` because it explains why syncing isn't happening even more
  /// directly than "this launch fell back to local storage" does.
  var rowState: RowState {
    switch accountStatus {
    case .checking:
      return .checking
    case .noAccount:
      return .unavailable
    case .restricted:
      return .restricted
    case .temporarilyUnavailable:
      return .needsAttention
    case .couldNotDetermine:
      return .couldNotCheck
    case .available:
      break
    }
    if containerBacking == .localFallback {
      return .paused
    }
    return syncFailureRowState ?? .available
  }

  /// Folds one finished `NSPersistentCloudKitContainer` event into `syncActivity`. A success clears
  /// only its own operation's failure; it says nothing about the other two.
  func record(_ snapshot: SyncEventSnapshot) {
    var state = syncActivity[snapshot.operation] ?? SyncOperationState()
    if let error = snapshot.error {
      state.latestFailure = error
    } else {
      state.lastSuccess = snapshot.endDate
      state.latestFailure = nil
    }
    syncActivity[snapshot.operation] = state
  }

  /// `nil` when no recorded failure should change the row: none recorded, or only the transient
  /// errors that never do (`NSPersistentCloudKitContainer` retries them on its own).
  private var syncFailureRowState: RowState? {
    let failures = syncActivity.values.compactMap(\.latestFailure)
    guard !failures.isEmpty else { return nil }
    if failures.contains(where: Self.isStorageFull) { return .storageFull }
    guard failures.contains(where: { !Self.isIgnoredTransientFailure($0) }) else { return nil }
    return .syncInterrupted
  }

  private static func isStorageFull(_ error: SyncErrorCode) -> Bool {
    error.domain == CKErrorDomain && CKError.Code(rawValue: error.code) == .quotaExceeded
  }

  private static let ignoredTransientCodes: Set<CKError.Code> = [
    .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy,
  ]

  private static func isIgnoredTransientFailure(_ error: SyncErrorCode) -> Bool {
    guard error.domain == CKErrorDomain, let code = CKError.Code(rawValue: error.code) else { return false }
    return ignoredTransientCodes.contains(code)
  }
}

/// An `NSError`'s domain and code, with no `userInfo` — the shape the analytics deny-list and the
/// Feedback diagnostics both require. `analytics-spec.md §Deny-list`.
struct SyncErrorCode: Equatable {
  let domain: String
  let code: Int
}

/// The three CloudKit sync operations `NSPersistentCloudKitContainer` reports. Raw values are the
/// `sync_operation` analytics vocabulary.
enum SyncOperation: String, CaseIterable, Hashable {
  case setup
  case `import`
  case export
}

/// Last success and latest failure for one `SyncOperation`, this launch only.
struct SyncOperationState: Equatable {
  var lastSuccess: Date?
  var latestFailure: SyncErrorCode?
}

/// A finished `NSPersistentCloudKitContainer.Event`, reduced to what `SyncStatus.record(_:)` needs.
/// A plain struct because the real `Event` type cannot be constructed in tests — all monitor logic
/// goes through this instead.
struct SyncEventSnapshot {
  let operation: SyncOperation
  let endDate: Date
  let error: SyncErrorCode?
}
