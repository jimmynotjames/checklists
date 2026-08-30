//
//  AppLoggers.swift
//  checklists
//
//  Copyright © 2026 Jimmy Ho. All rights reserved.
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
// It is also durable in a way an analytics call is not: `os_log` hands the message to the logging
// daemon synchronously, so it survives the `fatalError` that follows it in `DBManager`. A
// buffered network event would not.
//
// **Note this uses `os_log` rather than the nicer `Logger` API.** `Logger` requires iOS 14 and
// this app deploys to iOS 13.2. If the deployment target is ever raised, this file and the two
// call sites in `DBManager` are the only places to migrate — tracked in issue #119.

import Foundation
import os

enum AppLog {
  private static let subsystem = Bundle.main.bundleIdentifier ?? "com.jimmyho.checklists"

  /// Realm failures — opening the store, and write transactions. Success paths log nothing.
  static let persistence = OSLog(subsystem: subsystem, category: "persistence")
}
