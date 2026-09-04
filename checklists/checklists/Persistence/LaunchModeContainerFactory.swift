//
//  LaunchModeContainerFactory.swift
//  checklists
//

import Foundation
import SwiftData

/// Chooses between the real store and a disposable one, based on how the process was launched.
enum LaunchModeContainerFactory {
  /// True when the process was started by an automated test.
  ///
  /// `-UITests1` is the long-standing launch argument the XCUITest bundle passes; `IS_TESTING` is
  /// the environment variable set on the scheme's test action, which also covers the unit-test
  /// host. Either one means: never touch the user's real store, never import, never sync.
  static var isRunningTests: Bool {
    CommandLine.arguments.contains("-UITests1")
      || ProcessInfo.processInfo.environment["IS_TESTING"] != nil
  }

  static func make() throws -> (container: ModelContainer, backing: ContainerBacking) {
    if isRunningTests {
      AppLog.bootstrap.info("bootstrap.launchMode: test (in-memory, seeded)")
      return try (InMemoryModelContainer.makeSeeded(), .localFallback)
    }
    return try ProductionContainerFactory.make()
  }
}
