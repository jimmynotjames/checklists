//
//  SaveFailureNotifier.swift
//  checklists
//

import Foundation

/**
 Tells the person when an edit could not be saved, from the one place every save passes through.

 `saveChanges` calls this, so every screen gets the message without a presenter of its own, and a
 feature added later gets it for free. Process-wide for the same reason as `AppAnalytics`: the
 persistence call sites have no environment to read a presenter from. Nothing installed — tests,
 previews — means nothing shown.
 */
@MainActor
enum SaveFailureNotifier {
  private(set) static var handler: (() -> Void)?

  static func install(_ handler: @escaping () -> Void) {
    self.handler = handler
  }

  static func saveFailed(during operation: PersistenceOperation) {
    saveFailed(during: operation, handler: handler)
  }

  /// The installed handler passed in rather than read, so tests can observe it without touching
  /// process-wide state.
  static func saveFailed(during operation: PersistenceOperation, handler: (() -> Void)?) {
    guard operation.notifiesOnFailure else { return }
    handler?()
  }
}

extension PersistenceOperation {
  /// Whether a failed save of this kind is shown to the person. Not for a failed import or seed,
  /// which reaches the failure screen instead, nor for dedupe, which cleans up after sync rather than
  /// after anything the person did (its failure is dropped on purpose; reason at its `try?` in
  /// `AppStartupCoordinator`).
  var notifiesOnFailure: Bool {
    switch self {
    case .checklistEdit, .itemEdit, .itemUpdate, .reorder, .delete: true
    case .legacyImport, .sampleSeed, .dedupe: false
    }
  }
}
