//
//  ICloudStatusLoader.swift
//  checklists
//

import CloudKit
import Foundation

/// Queries the iCloud account status and writes the mapped result into
/// `SyncStatus.accountStatus` — the half of the Settings iCloud row that would
/// otherwise be unreachable from unit tests because `CKContainer` cannot be
/// stubbed. The query is an injected closure: production uses the live
/// `CKContainer` call below; tests inject available / unavailable / throwing
/// providers.
struct ICloudStatusLoader {
  /// Returns the live account status.
  var accountStatus: () async throws -> CKAccountStatus = {
    #if DEBUG
      // UI tests: CKContainer.accountStatus() hangs on the account-less
      // Simulator, pinning the iCloud row to a spinner so XCUITest can't open
      // Settings. Skip the query; `.noAccount` maps to `.unavailable` in
      // `load(into:)`. DEBUG-only.
      if ProcessInfo.processInfo.environment["IS_TESTING"] != nil
        || CommandLine.arguments.contains("-UITests1") {
        return .noAccount
      }
    #endif
    return try await CKContainer.default().accountStatus()
  }

  /// Queries the provider, maps the result (`.available` → available, anything
  /// else or a thrown error → unavailable), writes it into `syncStatus`, and
  /// logs state transitions.
  func load(into syncStatus: SyncStatus) async {
    let old = syncStatus.accountStatus
    do {
      let status = try await accountStatus()
      syncStatus.accountStatus = status == .available ? .available : .unavailable
    } catch {
      syncStatus.accountStatus = .unavailable
    }
    let new = syncStatus.accountStatus
    if old != new {
      AppLog.cloudKit.notice("cloudkit.account.transition: \(String(describing: old), privacy: .public) → \(String(describing: new), privacy: .public)")
    }
  }
}
