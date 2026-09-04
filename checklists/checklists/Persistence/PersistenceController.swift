//
//  PersistenceController.swift
//  checklists
//

import Foundation
import SwiftData

/**
 Process-wide handle on the live persistence stack.

 Deliberately the same shape as the `DBManager` singleton it replaces: view controllers reach for
 the current context rather than having one threaded through three layers of initializers. The
 difference is that this one is *installed* at launch rather than lazily creating itself, so the
 failure path is a screen the user can act on instead of a crash inside a static initializer, and
 tests can install their own in-memory stack.
 */
@MainActor
final class PersistenceController {
  private static var installed: PersistenceController?

  /// The installed controller. Reading this before `install(_:)` is a programmer error: every
  /// screen is created by `AppStartupCoordinator` only after the container exists.
  static var shared: PersistenceController {
    guard let installed else {
      preconditionFailure("PersistenceController.shared read before install(_:). Startup order is wrong.")
    }
    return installed
  }

  let modelContainer: ModelContainer
  let containerBacking: ContainerBacking

  var mainContext: ModelContext {
    modelContainer.mainContext
  }

  init(modelContainer: ModelContainer, containerBacking: ContainerBacking) {
    self.modelContainer = modelContainer
    self.containerBacking = containerBacking
  }

  static func install(_ controller: PersistenceController) {
    installed = controller
  }
}
