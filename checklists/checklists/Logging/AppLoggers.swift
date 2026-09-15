//
//  AppLoggers.swift
//  checklists
//

// MARK: - Diagnostic logging, deliberately separate from analytics

//
// This is the *diagnostics* channel: operational failures that a developer needs to see when
// something goes wrong on a real device. It is architecturally independent of
// `AnalyticsClient`, which is the *product* channel (what users do). The two never feed each
// other — that is why they live in separate directories. See core-docs/analytics-spec.md §11 and
// the same split in the sibling `simple-recurring-budgets` repo.
//
// Why this exists: analytics are consent-gated and network-buffered, so they are not a record you
// can rely on — an opted-out install sends nothing at all, and an event queued for HTTP does not
// survive a trap. Without this channel, a store failure would crash the app having left no record
// anywhere. `os_log` needs no backend, no SDK, and no
// network — it writes to the unified log, which is readable in Console.app on an attached device
// and is captured in a sysdiagnose.
//
// It is also more durable than an analytics call would be: `os_log` writes synchronously into the
// shared log buffer, and only the flush to `logd`'s on-disk store is asynchronous. That is not a
// hard guarantee of persistence across the `fatalError` in `DBManager` — but a `.fault` logged
// immediately before a trap does survive in practice, which is more than can be said for a
// buffered network event. This was verified by corrupting the Realm file on a simulator and
// reading the fault back out of the unified log after the crash.
//
// Migrated from `os_log` to the nicer `Logger` API now that the deployment target is iOS 26
// (Logger requires iOS 14+). Closes #119.

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
