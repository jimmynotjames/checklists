//
//  SyncDiagnostics.swift
//  checklists
//

import Foundation

/// English, no-identifiers sync status block appended to the Feedback email body — for reading, not
/// translating. Pure, so every `SyncStatus` shape is coverable without a container.
/// `analytics-spec.md`'s deny-list still applies: nothing here comes from `NSError.userInfo` or
/// `localizedDescription`.
enum SyncDiagnostics {
  private static let dateFormatter = ISO8601DateFormatter()

  static func report(syncStatus: SyncStatus, appVersion: String, build: String, osVersion: String) -> String {
    var lines = [
      "--- Sync diagnostics ---",
      "App \(appVersion) (\(build)) · iOS \(osVersion)",
      "Store: \(syncStatus.containerBacking.rawValue)",
      "iCloud account: \(syncStatus.accountStatus.rawValue)",
      "Launch fallback: \(fallbackLine(syncStatus.fallbackError))",
    ]
    lines += SyncOperation.allCases.map { operation in
      operationLine(operation, state: syncStatus.syncActivity[operation])
    }
    return lines.joined(separator: "\n")
  }

  private static func fallbackLine(_ error: SyncErrorCode?) -> String {
    guard let error else { return "none" }
    return "\(error.domain) \(error.code)"
  }

  private static func operationLine(_ operation: SyncOperation, state: SyncOperationState?) -> String {
    if let failure = state?.latestFailure {
      let lastOk = state?.lastSuccess.map { "last ok \(dateFormatter.string(from: $0))" } ?? "no prior success"
      return "\(operation.rawValue): failed \(failure.domain) \(failure.code) (\(lastOk))"
    }
    if let lastSuccess = state?.lastSuccess {
      return "\(operation.rawValue): ok \(dateFormatter.string(from: lastSuccess))"
    }
    return "\(operation.rawValue): no activity"
  }
}
