//
//  AppLoggers.swift
//  checklists
//

// Diagnostics channel, independent of AnalyticsClient (the product channel). See
// analytics-spec.md §OSLog boundary.

import Foundation
import os

enum AppLog {
  private static let subsystem = Bundle.main.bundleIdentifier ?? "com.jimmyho.checklists"

  /// Store failures — opening the container, and save failures. Also carries the one-time
  /// Realm-to-SwiftData import's outcome and elapsed time. Success paths otherwise log nothing.
  static let persistence = Logger(subsystem: subsystem, category: "persistence")

  /// Which store backed this launch (CloudKit or the local fallback) and iCloud account-status
  /// transitions. Sync itself is the system's business; this is only what the app decided.
  static let cloudKit = Logger(subsystem: subsystem, category: "cloudkit")

  /// Launch sequencing: which startup path ran, and why the first screen was what it was.
  static let bootstrap = Logger(subsystem: subsystem, category: "bootstrap")
}
