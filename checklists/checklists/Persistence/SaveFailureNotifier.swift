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
  /// Whether a failed save of this kind is shown to the person. Startup's saves are not: a failed
  /// import or seed reaches the failure screen instead, and a failed dedupe is dropped on purpose
  /// (reason at its `try?` in `AppStartupCoordinator`).
  var notifiesOnFailure: Bool {
    switch self {
    case .checklistEdit, .itemEdit, .itemUpdate, .reorder, .delete: true
    case .legacyImport, .sampleSeed, .dedupe: false
    }
  }
}

extension Toast {
  static var saveFailed: Toast {
    Toast(
      message: LocalizedStringResource(
        "toast.saveFailed",
        defaultValue: "Save failed. Your device may be low on storage.",
        comment: """
        Error toast shown when a change could not be written to the device. Full storage is the \
        likely cause but not a certain one — a damaged database fails the same way — so the \
        second sentence must stay a guess ("may"), never a statement of fact. Appears briefly at \
        the bottom of the screen with no button. Keep it short; it can appear after any edit \
        (adding, ticking, renaming, deleting).
        """
      ),
      style: .error
    )
  }
}
