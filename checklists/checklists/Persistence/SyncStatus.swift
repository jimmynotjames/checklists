//
//  SyncStatus.swift
//  checklists
//

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

  /// Four-state row for Settings' iCloud row. Why `.paused` exists:
  /// persistence-design.md §Sync status.
  enum RowState {
    case checking
    case available
    case unavailable
    /// Local-only container despite a potentially available iCloud account.
    case paused
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
  var rowState: RowState {
    switch (containerBacking, accountStatus) {
    case (_, .checking):
      .checking
    case (.cloudKit, .available):
      .available
    case (.localFallback, .available):
      .paused
    case (.cloudKit, .noAccount),
         (.cloudKit, .restricted),
         (.cloudKit, .temporarilyUnavailable),
         (.cloudKit, .couldNotDetermine),
         (.localFallback, .noAccount),
         (.localFallback, .restricted),
         (.localFallback, .temporarilyUnavailable),
         (.localFallback, .couldNotDetermine):
      .unavailable
    }
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
