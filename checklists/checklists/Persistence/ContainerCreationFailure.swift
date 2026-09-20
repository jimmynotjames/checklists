//
//  ContainerCreationFailure.swift
//  checklists
//

import Foundation

/// The typed value carried when launch could not produce a usable store, tagged with how far it
/// got.
///
/// Holds only an `NSError`'s `domain` and `code` — never `localizedDescription`, never `userInfo`
/// — so it is safe to log publicly and to drop into a feedback email. `userInfo` can serialise
/// arbitrary content, some of which may be the user's own data.
/// Conforms to `Error` so each startup stage can rethrow its own failure tagged with its stage, and
/// the coordinator's single `catch` can bind it back.
struct ContainerCreationFailure: Error, Equatable, Hashable {
  /// Which startup stage threw.
  ///
  /// Set explicitly per `try` in `AppStartupCoordinator.run()` rather than inferred from the error:
  /// the legacy import throws Realm's errors and its own `ImportError`, neither of which says
  /// anything about the stage, and a `PersistenceError`'s `PersistenceOperation` answers "which
  /// save" rather than "how far did launch get".
  ///
  /// Raw values are sent as `startup_stage`, so these case names are analytics vocabulary — see
  /// core-docs/analytics-spec.md §9.1.
  enum Stage: String, CaseIterable {
    case storeOpen = "store_open"
    case legacyImport = "legacy_import"
    case firstLaunchSeed = "first_launch_seed"
  }

  let stage: Stage
  let errorDomain: String
  let errorCode: Int

  /// Whether the failure screen offers "Start over fresh".
  ///
  /// Only for `.storeOpen`. The other stages mean the store opened and may hold the user's real
  /// checklists, and `StoreReset.startOverFresh()` deletes them along with the Realm file — to fix
  /// a problem that involved neither. A stage added later has to opt in here deliberately.
  var allowsStoreReset: Bool {
    stage == .storeOpen
  }

  init(stage: Stage, errorDomain: String, errorCode: Int) {
    self.stage = stage
    self.errorDomain = errorDomain
    self.errorCode = errorCode
  }

  /// `PersistenceError` is unwrapped first. It is a Swift struct, so `as NSError` would bridge it
  /// to `domain = "checklists.PersistenceError", code = 1` — collapsing every import and seed save
  /// failure into one bucket while the real domain and code sit in its own fields.
  init(underlying: any Error, stage: Stage) {
    self.stage = stage
    if let persistenceError = underlying as? PersistenceError {
      errorDomain = persistenceError.errorDomain
      errorCode = persistenceError.errorCode
      return
    }
    let nsError = underlying as NSError
    errorDomain = nsError.domain
    errorCode = nsError.code
  }

  /// Terse, PII-free identifier for logs and the feedback mail body.
  var diagnosticDescription: String {
    "\(stage.rawValue) \(errorDomain) \(errorCode)"
  }
}
