//
//  AppLoggers.swift
//  checklists
//

// MARK: - Diagnostic logging, deliberately separate from analytics

//
// This is the *diagnostics* channel: operational failures that a developer needs to see when
// something goes wrong on a real device. It is architecturally independent of
// `AnalyticsManager`, which is the *product* channel (what users do). The two never feed each
// other. The same split is used in the sibling `budgets1` repo (`AppLoggers.swift` +
// `docs/analytics-spec.md` §17).
//
// Why this exists: analytics are currently stubbed (Flurry removed, Mixpanel not wired up), so
// `AnalyticsManager.log*` calls go nowhere in Release. Without this channel, a Realm failure
// would crash the app having left no record anywhere. `os_log` needs no backend, no SDK, and no
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

  /// Realm failures — opening the store, and write transactions. Success paths log nothing.
  static let persistence = Logger(subsystem: subsystem, category: "persistence")
}
