//
//  AnalyticsClientSelectionTests.swift
//  checklistsTests
//

@testable import checklists
import XCTest

/// `ChecklistsApp.makeAnalyticsClient()` is `private`, so it cannot be called directly from a
/// test — but its test guard is exactly `LaunchModeContainerFactory.isRunningTests`, and that is
/// what this asserts against, directly and without touching `Bundle.main` or
/// `ProcessInfo.processInfo`. core-docs/analytics-spec.md §13 contract 15: the client-selection
/// predicate must return true — meaning "use the console client" — for **both** signals, since
/// `budgets1`'s `IS_TESTING`-only check would let this app's XCUITest runs, which pass only the
/// launch argument, reach real Mixpanel.
nonisolated final class AnalyticsClientSelectionTests: XCTestCase {
  @MainActor
  func testUITestLaunchArgumentSelectsConsole() {
    XCTAssertTrue(
      LaunchModeContainerFactory.isRunningTests(arguments: ["-UITests1"], environment: [:])
    )
  }

  @MainActor
  func testIsTestingEnvironmentVariableSelectsConsole() {
    XCTAssertTrue(
      LaunchModeContainerFactory.isRunningTests(arguments: [], environment: ["IS_TESTING": "1"])
    )
  }

  @MainActor
  func testBothSignalsPresentSelectsConsole() {
    XCTAssertTrue(
      LaunchModeContainerFactory.isRunningTests(
        arguments: ["-UITests1"],
        environment: ["IS_TESTING": "1"]
      )
    )
  }

  @MainActor
  func testNeitherSignalPresentDoesNotSelectConsole() {
    XCTAssertFalse(
      LaunchModeContainerFactory.isRunningTests(arguments: [], environment: [:])
    )
  }

  @MainActor
  func testUnrelatedArgumentsAndEnvironmentDoNotSelectConsole() {
    XCTAssertFalse(
      LaunchModeContainerFactory.isRunningTests(
        arguments: ["-SomeOtherFlag"],
        environment: ["PATH": "/usr/bin"]
      )
    )
  }
}
