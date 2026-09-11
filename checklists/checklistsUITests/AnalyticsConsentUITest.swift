//
//  AnalyticsConsentUITest.swift
//  checklistsUITests
//

import XCTest

/// Exercises the first-run analytics consent sheet end-to-end: its trigger, decline, and
/// swipe-to-dismiss (core-docs/analytics-spec.md §6.2, §6.3). The unit-level
/// `AnalyticsConsentControllerTests` cover the ordering contract; this class covers presentation
/// — in particular, that a swipe-to-dismiss actually reaches the sheet's `.onDisappear` guard.
/// Without that, the sheet re-presents on every checklist open, and no unit test can see it.
///
/// Each test launches its own process with `-AppleLocale` forcing a specific region, so the
/// jurisdiction lookup in `ConsentJurisdiction` resolves deterministically regardless of the
/// simulator's own region setting. `AnalyticsSettings` resolves to a fresh in-memory store for
/// every one of these launches (`LaunchModeContainerFactory.isRunningTests`), so no test's
/// consent decision can leak into another's.
class AnalyticsConsentUITest: XCTestCase {
  private var app: XCUIApplication!

  override func tearDownWithError() throws {}

  /// The main checklists list is a SwiftUI `List`, which XCUITest exposes as a collection view
  /// (the detail screen behind it is still a UIKit table view — see `checklistUITest`).
  private var checklistsList: XCUIElementQuery {
    app.collectionViews
  }

  private var consentAcceptButton: XCUIElement {
    app.buttons["analyticsConsentSheet.accept"]
  }

  private var consentDeclineButton: XCUIElement {
    app.buttons["analyticsConsentSheet.decline"]
  }

  /// Launches with `-UITests1` plus `-AppleLocale <locale>`, so `Locale.current.region` resolves
  /// to `locale`'s region regardless of the simulator's own setting.
  private func launch(locale: String) {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["-UITests1", "-AppleLocale", locale]
    app.launch()
    XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5), "Main checklists list did not appear after launch.")
  }

  /// Returns to the checklists list from the detail screen, if a detail screen is up. A no-op
  /// otherwise, so it is safe to call after a sheet-only interaction that never pushed a detail
  /// screen change.
  private func returnToChecklistsListIfNeeded() {
    let backButton = app.navigationBars.buttons["Back"]
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
      "Consent sheet did not appear for a strict-jurisdiction region."
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
      "Sheet should be dismissed after a swipe-down."
    )

    returnToChecklistsListIfNeeded()
    checklistsList.staticTexts["Weekend Getaway Essentials"].tap()

    XCTAssertFalse(
      consentAcceptButton.waitForExistence(timeout: 3),
      "Swipe-to-dismiss must count as a decline, or the sheet re-presents on every checklist open."
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
      "Declining must mark the choice explicit, or the sheet re-presents."
    )
  }

  func testAutoOptinRegionNeverShowsTheSheet() {
    launch(locale: "en_US")

    checklistsList.staticTexts["Morning Routine"].tap()

    XCTAssertFalse(
      consentAcceptButton.waitForExistence(timeout: 3),
      "Auto-opt-in regions must never see the first-run sheet."
    )
  }
}
