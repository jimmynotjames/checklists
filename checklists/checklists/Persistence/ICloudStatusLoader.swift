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
    // Requires the `application-identifier` entitlement: without it CKContainer.default()
    // has no container to resolve and CloudKit raises the Objective-C exception
    // `CKException` ("containerIdentifier can not be nil"). That is not a Swift error, so
    // the `do`/`catch` below cannot intercept it and the process aborts. A build produced
    // with CODE_SIGNING_ALLOWED=NO is exactly that binary, which is why neither
    // scripts/build.sh nor the CI build passes that flag any more (#140).
    return try await CKContainer.default().accountStatus()
  }

  /// Queries the provider, maps the result (`.available` → available, anything
  /// else or a thrown error → unavailable), writes it into `syncStatus`, and
  /// logs state transitions.
  func load(into syncStatus: SyncStatus) async {
    let old = syncStatus.accountStatus

    let resolved: SyncStatus.AccountStatus
    do {
      let status = try await accountStatus()
      resolved = status == .available ? .available : .unavailable
    } catch {
      resolved = .unavailable
    }

    // A superseded query must not publish its answer. Cancellation in Swift is cooperative, so a
    // slow `CKContainer.accountStatus()` keeps running after its task is cancelled and resolves
    // later — potentially long after a newer query has already written a fresher, correct status.
    // Without this guard that stale answer wins, and a signed-in user can be left looking at
    // "iCloud Not Available" until the next account-change notification, which may never come in
    // that session.
    guard !Task.isCancelled else { return }

    syncStatus.accountStatus = resolved
    let new = syncStatus.accountStatus
    if old != new {
      AppLog.cloudKit.notice("cloudkit.account.transition: \(String(describing: old), privacy: .public) → \(String(describing: new), privacy: .public)")
    }
  }
}
