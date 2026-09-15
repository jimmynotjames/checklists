//
//  AnalyticsClientSelectionTests.swift
//  checklistsTests
//

@testable import checklists
import Testing

/// core-docs/analytics-spec.md §13 contract 15: the client-selection predicate must return
/// "use the console client" for **both** the `-UITests1` launch argument and the `IS_TESTING`
/// environment variable, since `simple-recurring-budgets`'s `IS_TESTING`-only check would let this
/// app's XCUITest
/// runs — which pass only the launch argument — reach real Mixpanel.
///
/// `ChecklistsApp.shouldUseConsoleClient(isRunningTests:isTokenConfigured:)` is the actual
/// predicate `makeAnalyticsClient()` calls, pulled out to `internal` specifically so this suite can
/// exercise the real decision rather than a stand-in for it. An earlier version of this file tested
/// only `LaunchModeContainerFactory.isRunningTests(arguments:environment:)` — correct in isolation,
/// but incapable of failing if `makeAnalyticsClient()` ever stopped consulting it (e.g. a
/// `simple-recurring-budgets`-style regression to checking only `IS_TESTING`), because nothing here
/// called through to
/// `ChecklistsApp` at all. Both levels are covered below: the signal-detection primitive, and the
/// selection truth table built on top of it.
@Suite("Analytics client selection")
struct AnalyticsClientSelectionTests {
  // MARK: - `ChecklistsApp.shouldUseConsoleClient` — the actual selection truth table

  @Test("running tests selects the console client regardless of token configuration")
  func usesConsoleWhenRunningTestsRegardlessOfTokenConfiguration() {
    #expect(ChecklistsApp.shouldUseConsoleClient(isRunningTests: true, isTokenConfigured: true))
    #expect(ChecklistsApp.shouldUseConsoleClient(isRunningTests: true, isTokenConfigured: false))
  }

  @Test("an unconfigured token selects the console client outside of tests")
  func usesConsoleWhenTokenIsNotConfiguredRegardlessOfTestRun() {
    #expect(ChecklistsApp.shouldUseConsoleClient(isRunningTests: false, isTokenConfigured: false))
  }

  @Test("Mixpanel is used only when not testing and the token is configured")
  func usesMixpanelOnlyWhenNotTestingAndTokenIsConfigured() {
    #expect(!ChecklistsApp.shouldUseConsoleClient(isRunningTests: false, isTokenConfigured: true))
  }

  // MARK: - `LaunchModeContainerFactory.isRunningTests` — the signal `shouldUseConsoleClient` consumes

  @Test("the -UITests1 launch argument is detected as running tests")
  func uiTestLaunchArgumentIsDetectedAsRunningTests() {
    #expect(
      LaunchModeContainerFactory.isRunningTests(arguments: ["-UITests1"], environment: [:])
    )
  }

  @Test("the IS_TESTING environment variable is detected as running tests")
  func isTestingEnvironmentVariableIsDetectedAsRunningTests() {
    #expect(
      LaunchModeContainerFactory.isRunningTests(arguments: [], environment: ["IS_TESTING": "1"])
    )
  }

  @Test("both signals present together are detected as running tests")
  func bothSignalsPresentIsDetectedAsRunningTests() {
    #expect(
      LaunchModeContainerFactory.isRunningTests(
        arguments: ["-UITests1"],
        environment: ["IS_TESTING": "1"]
      )
    )
  }

  @Test("neither signal present is not detected as running tests")
  func neitherSignalPresentIsNotDetectedAsRunningTests() {
    #expect(
      !LaunchModeContainerFactory.isRunningTests(arguments: [], environment: [:])
    )
  }

  @Test("unrelated arguments and environment variables are not detected as running tests")
  func unrelatedArgumentsAndEnvironmentAreNotDetectedAsRunningTests() {
    #expect(
      !LaunchModeContainerFactory.isRunningTests(
        arguments: ["-SomeOtherFlag"],
        environment: ["PATH": "/usr/bin"]
      )
    )
  }
}
