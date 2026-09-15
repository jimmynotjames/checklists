//
//  SyncStatus.swift
//  checklists
//

import Foundation
import Observation

/// Tracks the app's iCloud sync availability and exposes a derived view-state
/// for the Settings screen's iCloud row.
///
/// `containerBacking` is determined at app launch from the outcome of
/// `ProductionContainerFactory.make` and is not expected to change afterwards.
/// `accountStatus` is updated asynchronously by `SettingsView` via
/// `ICloudStatusLoader` and `CKAccountChangedNotification`/`NSUbiquityIdentityDidChange`
/// observers.
///
/// Ported from the sibling `simple-recurring-budgets` repo's `Sync/SyncStatus.swift`.
@Observable
final class SyncStatus {
  enum AccountStatus {
    case checking
    case available
    case unavailable
  }

  /// Four-state row for Settings' iCloud row. Why `.paused` exists:
  /// core-docs/persistence-design.md §Sync status.
  enum RowState {
    case checking
    case available
    case unavailable
    /// Local-only container despite a potentially available iCloud account.
    case paused
  }

  let containerBacking: ContainerBacking

  var accountStatus: AccountStatus

  init(containerBacking: ContainerBacking, accountStatus: AccountStatus = .checking) {
    self.containerBacking = containerBacking
    self.accountStatus = accountStatus
  }
}

extension SyncStatus {
  var rowState: RowState {
    switch (containerBacking, accountStatus) {
    case (_, .checking):
      .checking
    case (.cloudKit, .available):
      .available
    case (.cloudKit, .unavailable):
      .unavailable
    case (.localFallback, .available):
      .paused
    case (.localFallback, .unavailable):
      .unavailable
    }
  }
}
