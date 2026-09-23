//
//  PersistenceController.swift
//  checklists
//

import Foundation
import SwiftData

/// Process-wide handle on the live persistence stack. Installed at launch rather than lazily
/// created, so a failed store shows the failure screen instead of crashing.
@MainActor
final class PersistenceController {
  private static var installed: PersistenceController?

  /// The installed controller. Reading this before `install(_:)` is a programmer error: every
  /// screen is built from `ChecklistsApp`'s `.ready` phase, which exists only after
  /// `AppStartupCoordinator` has installed this.
  static var shared: PersistenceController {
    guard let installed else {
      preconditionFailure("PersistenceController.shared read before install(_:). Startup order is wrong.")
    }
    return installed
  }

  let modelContainer: ModelContainer
  let syncStatus: SyncStatus

  var mainContext: ModelContext {
    modelContainer.mainContext
  }

  init(modelContainer: ModelContainer, containerBacking: ContainerBacking) {
    self.modelContainer = modelContainer
    syncStatus = SyncStatus(containerBacking: containerBacking)
  }

  static func install(_ controller: PersistenceController) {
    installed = controller
  }
}
