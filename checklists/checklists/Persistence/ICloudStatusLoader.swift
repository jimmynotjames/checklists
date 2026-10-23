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
      // can't open Settings. `.noAccount` maps to `AccountStatus.noAccount`, rowState `.unavailable`.
      if ProcessInfo.processInfo.environment["IS_TESTING"] != nil
        || CommandLine.arguments.contains("-UITests1") {
        return .noAccount
      }
    #endif
    // Needs the application-identifier entitlement; without it CloudKit raises an uncatchable ObjC CKException. See scripts/build.sh.
    return try await CKContainer.default().accountStatus()
  }

  func load(into syncStatus: SyncStatus, analytics: any AnalyticsClient = AppAnalytics.shared) async {
    #if DEBUG
      // Xcode previews inject the status they want to show. The live CKContainer query would
      // overwrite it — and on an account-less simulator it hangs, pinning the row to its spinner.
      if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        return
      }
    #endif

    syncStatus.accountQueriesStarted += 1
    let query = syncStatus.accountQueriesStarted

    let resolved: SyncStatus.AccountStatus
    do {
      resolved = try await Self.map(accountStatus())
    } catch {
      resolved = .couldNotDetermine
    }

    // A superseded query must not publish its answer: a slow `CKContainer.accountStatus()` can
    // resolve after a later-started query already wrote a fresher status, and cancellation is
    // cooperative, so a cancelled one keeps running too. Without this guard, a signed-in user can
    // be stuck on "iCloud Not Available". A later query that is still pending doesn't block this
    // one: the call can hang, and an older answer beats none.
    guard !Task.isCancelled, query > syncStatus.newestPublishedAccountQuery else { return }
    syncStatus.newestPublishedAccountQuery = query

    let old = syncStatus.accountStatus
    syncStatus.accountStatus = resolved
    let new = syncStatus.accountStatus
    if old != new {
      AppLog.cloudKit.notice("cloudkit.account.transition: \(String(describing: old), privacy: .public) → \(String(describing: new), privacy: .public)")
    }

    reportInitialStatusIfNeeded(old: old, new: new, syncStatus: syncStatus, analytics: analytics)
  }

  /// Once per process, the first time the status leaves `.checking`. The flag lives on
  /// `syncStatus` (not a static) because the "load once" and "observe account changes" tasks in
  /// `ChecklistsApp` can both be in flight at launch and must not double-fire.
  private func reportInitialStatusIfNeeded(
    old: SyncStatus.AccountStatus,
    new: SyncStatus.AccountStatus,
    syncStatus: SyncStatus,
    analytics: any AnalyticsClient,
  ) {
    guard old == .checking, new != .checking, !syncStatus.hasReportedInitialAccountStatus else { return }
    syncStatus.hasReportedInitialAccountStatus = true
    analytics.track(
      AnalyticsEvent.icloudStatusChecked,
      properties: [
        AnalyticsProperty.containerBacking: syncStatus.containerBacking.rawValue,
        AnalyticsProperty.icloudAccount: new.rawValue,
      ],
    )
  }

  private static func map(_ status: CKAccountStatus) -> SyncStatus.AccountStatus {
    switch status {
    case .available: .available
    case .noAccount: .noAccount
    case .restricted: .restricted
    case .temporarilyUnavailable: .temporarilyUnavailable
    case .couldNotDetermine: .couldNotDetermine
    @unknown default: .couldNotDetermine
    }
  }
}
