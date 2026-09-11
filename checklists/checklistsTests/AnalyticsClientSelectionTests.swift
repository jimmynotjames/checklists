//
//  AnalyticsClientSelectionTests.swift
//  checklistsTests
//

@testable import checklists
import XCTest

/// core-docs/analytics-spec.md §13 contract 15: the client-selection predicate must return
/// "use the console client" for **both** the `-UITests1` launch argument and the `IS_TESTING`
/// environment variable, since `budgets1`'s `IS_TESTING`-only check would let this app's XCUITest
/// runs — which pass only the launch argument — reach real Mixpanel.
///
/// `ChecklistsApp.shouldUseConsoleClient(isRunningTests:isTokenConfigured:)` is the actual
/// predicate `makeAnalyticsClient()` calls, pulled out to `internal` specifically so this suite can
/// exercise the real decision rather than a stand-in for it. An earlier version of this file tested
/// only `LaunchModeContainerFactory.isRunningTests(arguments:environment:)` — correct in isolation,
/// but incapable of failing if `makeAnalyticsClient()` ever stopped consulting it (e.g. a
/// budgets1-style regression to checking only `IS_TESTING`), because nothing here called through to
/// `ChecklistsApp` at all. Both levels are covered below: the signal-detection primitive, and the
/// selection truth table built on top of it.
nonisolated final class AnalyticsClientSelectionTests: XCTestCase {
  // MARK: - `ChecklistsApp.shouldUseConsoleClient` — the actual selection truth table

  @MainActor
  func testUsesConsoleWhenRunningTestsRegardlessOfTokenConfiguration() {
    XCTAssertTrue(ChecklistsApp.shouldUseConsoleClient(isRunningTests: true, isTokenConfigured: true))
    XCTAssertTrue(ChecklistsApp.shouldUseConsoleClient(isRunningTests: true, isTokenConfigured: false))
  }

  @MainActor
  func testUsesConsoleWhenTokenIsNotConfiguredRegardlessOfTestRun() {
    XCTAssertTrue(ChecklistsApp.shouldUseConsoleClient(isRunningTests: false, isTokenConfigured: false))
  }

  @MainActor
  func testUsesMixpanelOnlyWhenNotTestingAndTokenIsConfigured() {
    XCTAssertFalse(ChecklistsApp.shouldUseConsoleClient(isRunningTests: false, isTokenConfigured: true))
  }

  // MARK: - `LaunchModeContainerFactory.isRunningTests` — the signal `shouldUseConsoleClient` consumes

  @MainActor
  func testUITestLaunchArgumentIsDetectedAsRunningTests() {
    XCTAssertTrue(
      LaunchModeContainerFactory.isRunningTests(arguments: ["-UITests1"], environment: [:])
    )
  }

  @MainActor
  func testIsTestingEnvironmentVariableIsDetectedAsRunningTests() {
    XCTAssertTrue(
      LaunchModeContainerFactory.isRunningTests(arguments: [], environment: ["IS_TESTING": "1"])
    )
  }

  @MainActor
  func testBothSignalsPresentIsDetectedAsRunningTests() {
    XCTAssertTrue(
      LaunchModeContainerFactory.isRunningTests(
        arguments: ["-UITests1"],
        environment: ["IS_TESTING": "1"]
      )
    )
  }

  @MainActor
  func testNeitherSignalPresentIsNotDetectedAsRunningTests() {
    XCTAssertFalse(
      LaunchModeContainerFactory.isRunningTests(arguments: [], environment: [:])
    )
  }

  @MainActor
  func testUnrelatedArgumentsAndEnvironmentAreNotDetectedAsRunningTests() {
    XCTAssertFalse(
      LaunchModeContainerFactory.isRunningTests(
        arguments: ["-SomeOtherFlag"],
        environment: ["PATH": "/usr/bin"]
      )
    )
  }
}
