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
  /// An item's checked state changing — one checkbox, or every item at once via Reset. Distinct
  /// from `itemEdit` because "update" means exactly this in the model layer, and `Checklist`
  /// stamps `lastUpdated` for it and for nothing else.
  case itemUpdate
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

  // The two helpers below pair a timestamp stamp with the save, rather than leaving each call site
  // to remember both halves. Both take `wasComplete`, read by the caller *before* it mutates,
  // because "became complete" is a transition and there is no way to see one after the fact.
  //
  // Guarding on `!wasComplete` is what keeps a list that was already complete from being restamped
  // by further ticking.

  /// A checkbox tap, or a Reset. Always an update; also a completion when this is the change that
  /// completed the list.
  func saveStatusChange(
    to checklist: Checklist,
    wasComplete: Bool,
    at date: Date = .now,
    analytics: any AnalyticsClient = AppAnalytics.shared
  ) {
    checklist.recordUpdate(at: date)
    if !wasComplete, checklist.isComplete {
      checklist.recordCompletion(at: date)
    }
    saveChangesIgnoringFailure(operation: .itemUpdate, analytics: analytics)
  }

  /// An item deletion. Deleting is an edit, so this never touches `lastUpdated` — but removing the
  /// one item still outstanding does complete the list, and that is worth recording.
  ///
  /// Completeness is re-read *after* the save, unlike `saveStatusChange` above. A deleted item is
  /// still present in `checklist.items` until the context is saved, so checking first would read
  /// the list as incomplete and silently miss every deletion that finishes one. The second save
  /// only happens on that transition, which is rare.
  func saveDeletion(
    from checklist: Checklist,
    wasComplete: Bool,
    at date: Date = .now,
    analytics: any AnalyticsClient = AppAnalytics.shared
  ) {
    saveChangesIgnoringFailure(operation: .delete, analytics: analytics)
    guard !wasComplete, checklist.isComplete else { return }
    checklist.recordCompletion(at: date)
    saveChangesIgnoringFailure(operation: .delete, analytics: analytics)
  }
}
