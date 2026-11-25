//
//  AnalyticsConsentUITest.swift
//  checklistsUITests
//

import XCTest

/// Each test launches its own process with `-AppleLocale` forcing a specific region, so the
/// jurisdiction lookup in `ConsentJurisdiction` resolves deterministically regardless of the
/// simulator's own region setting. `AnalyticsSettings` resolves to a fresh in-memory store for
/// every one of these launches (`LaunchModeContainerFactory.isRunningTests`), so no test's
/// consent decision can leak into another's.
class AnalyticsConsentUITest: XCTestCase {
  private var app: XCUIApplication!

  override func tearDownWithError() throws {}

  /// See ChecklistDetailUITestCase.checklistsList.
  private var checklistsList: XCUIElementQuery {
    app.collectionViews
  }

  private var consentAcceptButton: XCUIElement {
    app.buttons["analyticsConsentSheet.accept"]
  }

  private var consentDeclineButton: XCUIElement {
    app.buttons["analyticsConsentSheet.decline"]
  }

  /// Launches with `configureForUITests()` plus `-AppleLocale <locale>`, so `Locale.current.region` resolves
  /// to `locale`'s region regardless of the simulator's own setting.
  private func launch(locale: String, screenshotSeedJSON: String? = nil) {
    continueAfterFailure = false
    app = XCUIApplication()
    app.configureForUITests(extraArguments: ["-AppleLocale", locale])
    if let screenshotSeedJSON {
      app.launchEnvironment["SEED_SCREENSHOTS_JSON"] = screenshotSeedJSON
      app.launchEnvironment["SCREENSHOT_SEED_LOCALE"] = "consent-regression"
    }
    app.launch()
    XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5), "Main checklists list did not appear after launch.")
  }

  /// Returns to the checklists list from the detail screen, if a detail screen is up. A no-op
  /// otherwise, so it is safe to call after a sheet-only interaction that never pushed a detail
  /// screen change.
  private func returnToChecklistsListIfNeeded() {
    let backButton = app.navigationBars.buttons["BackButton"]
    guard backButton.waitForExistence(timeout: 3) else { return }
    backButton.tap()
  }

  /// `app.swipeDown()` is a short, fixed-distance gesture that starts near the very top of the
  /// screen — inside the small scrim gap above a large-detent sheet, not on the sheet itself — so
  /// it does not reach SwiftUI's interactive-dismiss threshold. Dragging manually from just below
  /// the sheet's own top edge to near the bottom of the screen does.
  private func swipeSheetDownToDismiss() {
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
    start.press(forDuration: 0.05, thenDragTo: end)
  }

  // MARK: - Tests

  func testStrictRegionShowsSheetOnFirstPushedChecklist() {
    launch(locale: "de_DE")

    checklistsList.staticTexts["Morning Routine"].tap()

    XCTAssertTrue(
      consentAcceptButton.waitForExistence(timeout: 5),
      "Consent sheet did not appear for a strict-jurisdiction region.",
    )
  }

  /// The highest-value test in this file: if swipe-to-dismiss fails to reach the sheet's
  /// `.onDisappear` → decline path, the sheet re-presents on every checklist open, forever.
  func testSwipeToDismissDoesNotReappearOnAnotherChecklistOpen() {
    launch(locale: "de_DE")

    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(consentAcceptButton.waitForExistence(timeout: 5), "Consent sheet did not appear.")

    swipeSheetDownToDismiss()
    XCTAssertFalse(
      consentAcceptButton.waitForExistence(timeout: 3),
      "Sheet should be dismissed after a swipe-down.",
    )

    returnToChecklistsListIfNeeded()
    checklistsList.staticTexts["Weekend Getaway Essentials"].tap()

    XCTAssertFalse(
      consentAcceptButton.waitForExistence(timeout: 3),
      "Swipe-to-dismiss must count as a decline, or the sheet re-presents on every checklist open.",
    )
  }

  func testDeclineDoesNotReappearOnAnotherChecklistOpen() {
    launch(locale: "de_DE")

    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(consentDeclineButton.waitForExistence(timeout: 5), "Consent sheet did not appear.")
    consentDeclineButton.tap()

    returnToChecklistsListIfNeeded()
    checklistsList.staticTexts["Weekend Getaway Essentials"].tap()

    XCTAssertFalse(
      consentAcceptButton.waitForExistence(timeout: 3),
      "Declining must mark the choice explicit, or the sheet re-presents.",
    )
  }

  func testAutoOptinRegionNeverShowsTheSheet() {
    launch(locale: "en_US")

    checklistsList.staticTexts["Morning Routine"].tap()

    // Positive assertion first: without it, this test would also pass if navigation into the
    // checklist failed entirely, since the sheet would then also be absent for the wrong reason.
    XCTAssertTrue(
      app.tables["ChecklistTableView"].waitForExistence(timeout: 5),
      "Checklist detail screen did not appear.",
    )
    XCTAssertFalse(
      consentAcceptButton.waitForExistence(timeout: 3),
      "Auto-opt-in regions must never see the first-run sheet.",
    )
  }

  func testStrictRegionScreenshotLaunchDoesNotShowConsentSheet() {
    let checklistID = "C4EC1157-0000-4000-A000-000000000167"
    let seed = """
    {
      "schemaVersion": 1,
      "locale": "consent-regression",
      "primaryLocale": "de_DE",
      "checklists": [
        {
          "id": "\(checklistID)",
          "name": "Consent Regression",
          "items": [{"name": "Ready", "isChecked": false}]
        }
      ]
    }
    """
    launch(locale: "de_DE", screenshotSeedJSON: seed)

    let checklistRow = app.buttons["checklistRow.\(checklistID)"]
    XCTAssertTrue(checklistRow.waitForExistence(timeout: 5), "Seeded checklist row did not appear.")
    checklistRow.tap()
    XCTAssertTrue(
      app.tables["ChecklistTableView"].waitForExistence(timeout: 5),
      "Seeded checklist detail screen did not appear.",
    )
    XCTAssertFalse(
      consentAcceptButton.waitForExistence(timeout: 3),
      "Screenshot launch must start with an explicit opt-out in a strict region.",
    )
    XCTAssertFalse(
      consentDeclineButton.waitForExistence(timeout: 1),
      "Screenshot launch must not present either consent action.",
    )
  }
}
