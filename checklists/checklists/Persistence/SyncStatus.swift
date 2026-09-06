//
//  SyncStatus.swift
//  checklists
//

import Foundation
import Observation

// MARK: - SyncStatus

/// Tracks the app's iCloud sync availability and exposes a derived view-state
/// for the Settings screen's iCloud row.
///
/// `containerBacking` is determined at app launch from the outcome of
/// `ProductionContainerFactory.make` and is not expected to change afterwards.
/// `accountStatus` is updated asynchronously by `SettingsViewController` via
/// `ICloudStatusLoader` and `CKAccountChangedNotification`/`NSUbiquityIdentityDidChange`
/// observers.
///
/// Ported from the sibling `budgets1` repo's `Sync/SyncStatus.swift`.
@Observable
final class SyncStatus {
  // MARK: - Nested types

  /// The last-known iCloud account status.
  /// Initialized to `.checking`; updated by `SettingsViewController`.
  enum AccountStatus {
    case checking
    case available
    case unavailable
  }

  /// Four-state row view-state for the Settings iCloud row.
  ///
  /// Two independent signals feed this instead of one because they mean different things and can
  /// disagree: `containerBacking` says which store this *launch* ended up on, while
  /// `accountStatus` says whether the user is *currently* signed in to iCloud. `.paused` is the
  /// state where they disagree — signed in, but this launch's container fell back to the local
  /// store anyway (CloudKit container construction failed at launch, e.g. transient network or
  /// entitlement trouble). Collapsing the two signals into one would either hide that the user's
  /// edits are safe but not syncing, or wrongly tell a signed-in user to sign in again — `.paused`
  /// exists to say instead: your data is safe on this device, it just isn't syncing this launch,
  /// and relaunching may fix it.
  enum RowState {
    /// Initial state while the account query is in-flight.
    case checking
    /// CloudKit-backed container and an available iCloud account.
    case available
    /// CloudKit-backed container but no iCloud account (not signed in).
    case unavailable
    /// Local-only container despite a potentially available iCloud account.
    case paused
  }

  // MARK: - State

  /// Launch-time backing, read from `SettingsViewController`.
  let containerBacking: ContainerBacking

  /// Mutable account status. Updated by `SettingsViewController` asynchronously.
  var accountStatus: AccountStatus

  // MARK: - Init

  init(containerBacking: ContainerBacking, accountStatus: AccountStatus = .checking) {
    self.containerBacking = containerBacking
    self.accountStatus = accountStatus
  }
}

// MARK: - Derived row state

extension SyncStatus {
  /// Derives the Settings iCloud row view-state from `(containerBacking, accountStatus)`.
  ///
  /// Mapping:
  ///
  /// | containerBacking | accountStatus | rowState   |
  /// |------------------|---------------|------------|
  /// | any              | .checking     | .checking  |
  /// | .cloudKit        | .available    | .available |
  /// | .cloudKit        | .unavailable  | .unavailable |
  /// | .localFallback   | .available    | .paused    |
  /// | .localFallback   | .unavailable  | .unavailable |
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
