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
   Saves, and on failure logs a diagnostic, reports an analytics event, tells the person through
   `SaveFailureNotifier`, and throws.

   What it throws is a `PersistenceError`, not what `save()` gave it. The original `NSError` carries
   `userInfo`; a typed value holding only the operation, domain and code can be logged, mailed and
   re-thrown without anyone downstream having to remember that.

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
        // One literal so os_log keeps the privacy annotations; it can't be split to fit.
        // swiftlint:disable:next line_length
        "Save failed during \(operation.rawValue, privacy: .public): \(error.domain, privacy: .public) \(error.code, privacy: .public) \(error.localizedDescription, privacy: .public) | \(error.description, privacy: .private)",
      )
      analytics.track(
        AnalyticsEvent.persistenceWriteFailed,
        properties: [
          AnalyticsProperty.errorDomain: error.domain,
          AnalyticsProperty.errorCode: error.code,
          AnalyticsProperty.errorOperation: operation.rawValue,
        ],
      )
      SaveFailureNotifier.saveFailed(during: operation)
      throw PersistenceError(operation: operation, errorDomain: error.domain, errorCode: error.code)
    }
  }

  /**
   Saves, and on failure lets the error go after `saveChanges` has logged and reported it.

   For incidental edits — a renamed checklist, a toggled checkbox — where the caller has no useful
   recovery; the person still hears about it from `saveChanges`. The stages that can fail startup use the throwing form instead, so a failure there
   reaches the failure screen rather than being dropped.

   Dropping the error does not by itself mean the write is lost: see persistence-design.md
   §Autosave.
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
    analytics: any AnalyticsClient = AppAnalytics.shared,
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
    analytics: any AnalyticsClient = AppAnalytics.shared,
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
