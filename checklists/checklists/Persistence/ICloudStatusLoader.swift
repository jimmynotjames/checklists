//
//  ICloudStatusLoader.swift
//  checklists
//

import CloudKit
import Foundation

/// Queries the iCloud account status and writes the mapped result into `SyncStatus.accountStatus`.
/// The query is an injected closure — production uses the live `CKContainer` call below, tests
/// inject available/unavailable/throwing providers, since `CKContainer` cannot be stubbed directly.
struct ICloudStatusLoader {
  /// Returns the live account status.
  var accountStatus: () async throws -> CKAccountStatus = {
    #if DEBUG
      // Test runs (see `LaunchModeContainerFactory.isRunningTests`): CKContainer.accountStatus()
      // hangs on the account-less Simulator, pinning the iCloud row to a spinner so XCUITest
      // can't open Settings. `.noAccount` maps to `.unavailable` in `load(into:)`.
      if ProcessInfo.processInfo.environment["IS_TESTING"] != nil
        || CommandLine.arguments.contains("-UITests1") {
        return .noAccount
      }
    #endif
    // Needs the application-identifier entitlement; without it CloudKit raises an uncatchable ObjC CKException. See scripts/build.sh.
    return try await CKContainer.default().accountStatus()
  }

  func load(into syncStatus: SyncStatus) async {
    #if DEBUG
      // Xcode previews inject the status they want to show. The live CKContainer query would
      // overwrite it — and on an account-less simulator it hangs, pinning the row to its spinner.
      if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
    #endif

    let old = syncStatus.accountStatus

    let resolved: SyncStatus.AccountStatus
    do {
      let status = try await accountStatus()
      resolved = status == .available ? .available : .unavailable
    } catch {
      resolved = .unavailable
    }

    // A superseded query must not publish its answer: cancellation is cooperative, so a slow
    // `CKContainer.accountStatus()` keeps running and can resolve after a newer query already wrote
    // a fresher status. Without this guard, a signed-in user can be stuck on "iCloud Not Available".
    guard !Task.isCancelled else { return }

    syncStatus.accountStatus = resolved
    let new = syncStatus.accountStatus
    if old != new {
      AppLog.cloudKit.notice("cloudkit.account.transition: \(String(describing: old), privacy: .public) → \(String(describing: new), privacy: .public)")
    }
  }
}
