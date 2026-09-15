//
//  ModelContext+SaveChanges.swift
//  checklists
//

import Foundation
import SwiftData

/// What was being written when a save failed. Recorded in diagnostics so a failure can be traced
/// to a call site without a stack trace.
/// `CaseIterable` so `AnalyticsNamesTests` can pin the value set: `rawValue` is transmitted as
/// `error_operation`, which makes these case names part of the analytics vocabulary.
enum PersistenceOperation: String, CaseIterable {
  case checklistEdit
  case itemEdit
  case reorder
  case delete
  case legacyImport
  case sampleSeed
  case dedupe
}

/// A save failure, reduced to the parts that are safe to log and to show in a feedback mail.
struct PersistenceError: Error, Equatable {
  let operation: PersistenceOperation
  let errorDomain: String
  let errorCode: Int

  var diagnosticDescription: String {
    "\(operation.rawValue) \(errorDomain) \(errorCode)"
  }
}

extension ModelContext {
  /**
   Saves, and on failure logs a diagnostic and reports an analytics event before rethrowing.

   Unlike the old `DBManager.write` wrapper, which called `fatalError` on a failed write, the error
   is surfaced instead — each call site decides what to do (see `saveChangesIgnoringFailure`).

   The public/private split in the log line is inherited from `DBManager`: domain, code and
   `localizedDescription` are bounded, framework-authored strings and are what make a sysdiagnose
   actionable; the full error description can serialise `userInfo`, which is not bounded and not
   ours to promise is free of the user's own content.
   */
  func saveChanges(operation: PersistenceOperation, analytics: any AnalyticsClient = AppAnalytics.shared) throws {
    do {
      try save()
    } catch let error as NSError {
      AppLog.persistence.error(
        "Save failed during \(operation.rawValue, privacy: .public): \(error.domain, privacy: .public) \(error.code, privacy: .public) \(error.localizedDescription, privacy: .public) | \(error.description, privacy: .private)"
      )
      analytics.track(
        AnalyticsEvent.persistenceWriteFailed,
        properties: [
          AnalyticsProperty.errorDomain: error.domain,
          AnalyticsProperty.errorCode: error.code,
          AnalyticsProperty.errorOperation: operation.rawValue,
        ]
      )
      throw PersistenceError(operation: operation, errorDomain: error.domain, errorCode: error.code)
    }
  }

  /**
   Saves, and on failure lets the error go after `saveChanges` has logged and reported it.

   For incidental edits — a renamed checklist, a toggled checkbox — where there is no useful
   recovery and no sensible place to put an alert; the bet is that these saves do not fail in
   practice. Startup and import paths do **not** use this.
   */
  func saveChangesIgnoringFailure(operation: PersistenceOperation, analytics: any AnalyticsClient = AppAnalytics.shared) {
    try? saveChanges(operation: operation, analytics: analytics)
  }
}
