//
//  SyncStatus.swift
//  checklists
//

import Foundation
import Observation

/// Combines this launch's `ContainerBacking` with the live iCloud account status into the Settings
/// screen's iCloud row. `accountStatus` is written by `SettingsView` via `ICloudStatusLoader`.
/// Why the two signals stay apart: persistence-design.md §Sync status.
@Observable
final class SyncStatus {
  enum AccountStatus {
    case checking
    case available
    case unavailable
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
