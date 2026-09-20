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
  /// An item's checked state changing — one checkbox, or every item at once via Reset.
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
   Saves, and on failure logs a diagnostic, reports an analytics event, and throws.

   It throws a `PersistenceError` rather than rethrowing what `save()` gave it. That substitution is
   the point: the original `NSError` carries `userInfo`, and a typed value with only the operation,
   domain and code can be logged, mailed and re-thrown without anyone downstream having to remember
   that. `ContainerCreationFailure.init(underlying:stage:)` exists to unwrap it again.

   The public/private split in the log line follows from the same rule: domain, code and
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
   practice. The stages that can fail startup use the throwing form instead, so a failure there
   reaches the failure screen rather than being dropped. `AppStartupCoordinator`'s dedupe is the one
   startup call that swallows a failure, which it does with its own `try?` and for its own reason.

   Note that dropping the error is not the same as dropping the write: the main context autosaves
   (see core-docs/persistence-design.md §Autosave), so the pending changes usually reach disk
   shortly afterwards, with nothing reported either way.
   */
  func saveChangesIgnoringFailure(operation: PersistenceOperation, analytics: any AnalyticsClient = AppAnalytics.shared) {
    try? saveChanges(operation: operation, analytics: analytics)
  }

  // The two helpers below pair a timestamp stamp with the save, rather than leaving each call site
  // to remember both halves. Both take `wasComplete`, read by the caller *before* it mutates,
  // because "became complete" is a transition and there is no way to see one after the fact.

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
  /// Completeness is re-read *after* the save, unlike `saveStatusChange` above: a deleted item is
  /// still present in `checklist.items` until the context is saved, so checking first would read the
  /// list as incomplete and miss every deletion that finishes one.
  func saveDeletion(
    from checklist: Checklist,
    wasComplete: Bool,
    at date: Date = .now,
    analytics: any AnalyticsClient = AppAnalytics.shared
  ) {
    saveChangesIgnoringFailure(operation: .delete, analytics: analytics)
    // The checklist itself can be gone — deleted on another device while this screen was open — in
    // which case there is nothing left to record a completion on.
    guard !checklist.isDeleted, !wasComplete, checklist.isComplete else { return }
    checklist.recordCompletion(at: date)
    // Tagged for what it writes — a checklist timestamp — so a failure here is not counted as a
    // second failed deletion.
    saveChangesIgnoringFailure(operation: .checklistEdit, analytics: analytics)
  }
}
