//
//  LaunchModeContainerFactory.swift
//  checklists
//

import Foundation
import SwiftData

/// Chooses between the real store and a disposable one, based on how the process was launched.
enum LaunchModeContainerFactory {
  static let screenshotSeedJSONKey = "SEED_SCREENSHOTS_JSON"
  static let screenshotSeedLocaleKey = "SCREENSHOT_SEED_LOCALE"

  enum ScreenshotLaunchError: Error, Equatable {
    case missingLocale
    case requiresDebugBuild
  }

  /// True when the process was started by an automated test.
  ///
  /// `-UITests1` is the launch argument the XCUITest bundle passes; `IS_TESTING` is
  /// the environment variable set on the scheme's test action, which also covers the unit-test
  /// host. Either one means: never touch the user's real store, never import, never sync.
  static var isRunningTests: Bool {
    isRunningTests(
      arguments: CommandLine.arguments,
      environment: ProcessInfo.processInfo.environment
    )
  }

  static func make() throws -> ContainerLaunchResult {
    try make(
      arguments: CommandLine.arguments,
      environment: ProcessInfo.processInfo.environment
    )
  }

  static func isRunningTests(arguments: [String], environment: [String: String]) -> Bool {
    arguments.contains("-UITests1") || environment["IS_TESTING"] != nil
  }

  static func make(
    arguments: [String],
    environment: [String: String]
  ) throws -> ContainerLaunchResult {
    if isRunningTests(arguments: arguments, environment: environment) {
      if let json = environment[screenshotSeedJSONKey] {
        guard let locale = environment[screenshotSeedLocaleKey], !locale.isEmpty else {
          throw ScreenshotLaunchError.missingLocale
        }
        #if DEBUG
          let seed = try ScreenshotSeed.decode(from: json, expectedLocale: locale)
          AppLog.bootstrap.info("bootstrap.launchMode: screenshot test (in-memory, localized seed)")
          return try ContainerLaunchResult(
            container: InMemoryModelContainer.makeSeeded(with: seed),
            backing: .localFallback,
            fallbackError: nil
          )
        #else
          throw ScreenshotLaunchError.requiresDebugBuild
        #endif
      }

      AppLog.bootstrap.info("bootstrap.launchMode: test (in-memory, seeded)")
      return try ContainerLaunchResult(
        container: InMemoryModelContainer.makeSeeded(),
        backing: .localFallback,
        fallbackError: nil
      )
    }
    return try ProductionContainerFactory.make()
  }
}
