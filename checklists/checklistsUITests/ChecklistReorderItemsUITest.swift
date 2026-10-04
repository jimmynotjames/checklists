//
//  ChecklistReorderItemsUITest.swift
//  checklistsUITests
//

import XCTest

/// The checklist screen's Reorder Items mode.
///
/// Navigation-bar buttons are matched without naming the bar — see `checklistUITest.detailBackButton`
/// for why naming it makes a query depend on scroll position.
class ChecklistReorderItemsUITest: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["-UITests1"]
    app.launch()
    XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5), "Main checklists list did not appear after launch.")
  }

  /// See `checklistUITest.checklistsList`.
  private var checklistsList: XCUIElementQuery {
    app.collectionViews
  }

  private var detailBackButton: XCUIElement {
    app.navigationBars.buttons["Back"]
  }

  /// Reorder Items mode: the menu entry, the handles, Done, and a move that survives leaving the
  /// screen. The edge swipe is checked too, because the mode hides the back button it stands in for.
  func testReorderItemsMode() throws {
    checklistsList.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTableView.waitForExistence(timeout: 5))

    let moreButton = app.navigationBars.buttons["checklist.more"]
    XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "Overflow menu button didn't appear.")
    moreButton.tap()
    // Matched by identifier, which the localized screenshot capture relies on too.
    let reorderEntry = app.buttons["checklist.menu.reorderItems"]
    XCTAssertTrue(reorderEntry.waitForExistence(timeout: 5), "Reorder Items menu entry didn't appear.")
    reorderEntry.tap()

    let doneButton = app.navigationBars.buttons["checklist.reorderDone"]
    XCTAssertTrue(doneButton.waitForExistence(timeout: 5), "Reorder Items mode's Done didn't appear.")
    XCTAssertFalse(app.navigationBars.buttons["Reset"].exists, "The mode clears the bar down to Done.")

    // A left-edge swipe would leave the screen if the mode let it through.
    let window = app.windows.firstMatch
    window.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
    XCTAssertTrue(doneButton.exists, "An edge swipe left the screen in the middle of the mode.")

    let lastRow = checklistTableView.children(matching: .cell).element(boundBy: 5)
    let firstRow = checklistTableView.children(matching: .cell).element(boundBy: 0)
    let movedName = try XCTUnwrap(lastRow.textViews["itemNameTextView"].value as? String)
    let handle = lastRow.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder'")).firstMatch
    XCTAssertTrue(handle.waitForExistence(timeout: 5), "The row's drag handle didn't appear.")
    handle.press(forDuration: 0.5, thenDragTo: firstRow)

    let atIndex0 = try XCTUnwrap(firstRow.textViews["itemNameTextView"].value as? String)
    XCTAssertEqual(atIndex0, movedName)

    doneButton.tap()
    XCTAssertTrue(app.navigationBars.buttons["Reset"].waitForExistence(timeout: 5), "Done didn't put Reset back.")

    detailBackButton.tap()
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(checklistTableView.waitForExistence(timeout: 5))
    let reopenedFirst = try XCTUnwrap(
      checklistTableView.children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"].value as? String
    )
    XCTAssertEqual(reopenedFirst, movedName)
  }
}
