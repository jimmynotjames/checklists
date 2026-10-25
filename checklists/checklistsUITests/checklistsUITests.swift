//
//  checklistsUITests.swift
//  checklistsUITests
//
//  Created by Jimmy Ho on 5/7/19.
//

import XCTest

class checklistsUITests: XCTestCase {
  var app: XCUIApplication!

  override func setUp() {
    continueAfterFailure = false

    // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
    app = XCUIApplication()
    app.launchArguments = ["-UITests1"]
    app.launch()
    XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5), "Main checklists list did not appear after launch.")
  }

  func testChecklistDeletion() {
    // See ChecklistDetailUITestCase.checklistsList.
    let listQuery = app.collectionViews
    listQuery.staticTexts["Weekend Getaway Essentials"].swipeLeft()
    // The swipe action lives in the row, but scoping to `app` keeps this working regardless of
    // where the collection view hangs the revealed action button.
    let deleteAction = app.buttons["Delete"]
    XCTAssertTrue(deleteAction.waitForExistence(timeout: 5), "Swipe-to-delete action didn't appear.")
    deleteAction.tap()
    let confirmDelete = app.alerts.buttons["Delete"]
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete confirmation alert didn't appear.")
    confirmDelete.tap()

    let staticText1 = listQuery.staticTexts["Morning Routine"]
    let staticText2 = listQuery.staticTexts["Weekend Getaway Essentials"]
    let staticText3 = listQuery.staticTexts["Pre-Trip Checklist"]
    XCTAssert(staticText1.waitForExistence(timeout: 5))
    XCTAssert(staticText2.exists == false)
    XCTAssert(staticText3.exists)
  }

  /// The list screen's other swipe action. Delete keeps the outer edge, so both must be reachable
  /// after one swipe, and this one must act without a confirmation.
  func testChecklistDuplicationFromSwipe() {
    let listQuery = app.collectionViews
    let sourceName = "Weekend Getaway Essentials"
    listQuery.staticTexts[sourceName].swipeLeft()

    // By identifier rather than by label: Delete sits beside this one, and the revealed buttons are
    // not reliably enumerable by position straight after a swipe.
    let duplicateAction = app.buttons["checklistRow.duplicate"]
    XCTAssertTrue(duplicateAction.waitForExistence(timeout: 5), "Swipe-to-duplicate action didn't appear.")
    duplicateAction.tap()

    let copy = listQuery.staticTexts["\(sourceName) copy"]
    XCTAssertTrue(copy.waitForExistence(timeout: 5), "The copy didn't appear in the list.")
    // Nothing is confirmed and nothing is presented — the copy is simply there.
    XCTAssertFalse(app.alerts.firstMatch.exists, "Duplicating shouldn't raise a confirmation.")
    let source = listQuery.staticTexts[sourceName]
    XCTAssertTrue(source.exists, "The original should still be in the list.")
    XCTAssertGreaterThan(copy.frame.origin.y, source.frame.origin.y, "The copy should sit directly below the original.")

    // A second copy has to resolve its clash with the first rather than repeating the name.
    source.swipeLeft()
    XCTAssertTrue(duplicateAction.waitForExistence(timeout: 5), "Swipe-to-duplicate action didn't reappear.")
    duplicateAction.tap()
    XCTAssertTrue(
      listQuery.staticTexts["\(sourceName) copy 2"].waitForExistence(timeout: 5),
      "The second copy didn't get a name of its own.",
    )
  }

  func testChecklistReordering() {
    let text1 = app.staticTexts["Morning Routine"]
    let text2 = app.staticTexts["Weekend Getaway Essentials"]
    let text3 = app.staticTexts["Pre-Trip Checklist"]
    // Drag row 1 onto row 2, for the ordering 2, 1, 3.
    //
    // `.onMove` needs a long press to lift the row, then a slow drag and a hold at the end so the
    // list settles on the drop target before the touch lifts. It honours the full drag, so dropping
    // onto row 3 instead would land the row at the end (2, 3, 1).
    //
    // This is the first press after launch, which can take longer than a second to lift the row
    // under load; see `ChecklistDetailUITestCase.dragRow`.
    text1.press(forDuration: 1.5, thenDragTo: text2, withVelocity: .slow, thenHoldForDuration: 1.0)

    let moved = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in text1.frame.origin.y > text2.frame.origin.y },
      object: nil,
    )
    XCTAssertEqual(
      XCTWaiter().wait(for: [moved], timeout: 5), .completed,
      "Row 1 should have moved below row 2 (row 1 at y \(text1.frame.origin.y), row 2 at y \(text2.frame.origin.y)).",
    )
    XCTAssertGreaterThan(text3.frame.origin.y, text1.frame.origin.y, "Row 3 should still be below row 1.")
  }

  // MARK: - Edit mode

  /// Rows select rather than open, the toolbar waits for a selection, and the action ends Edit mode.
  func testEditModeDuplicatesSelection() {
    let listQuery = app.collectionViews
    enterEditMode()
    XCTAssertFalse(app.buttons["toolbar.addChecklist"].exists, "The add button should hide in Edit mode.")
    let duplicate = app.buttons["editBar.duplicate"]
    XCTAssertTrue(duplicate.waitForExistence(timeout: 5), "The Edit mode toolbar didn't appear.")
    XCTAssertFalse(duplicate.isEnabled, "Toolbar actions should wait for a selection.")

    listQuery.staticTexts["Morning Routine"].tap()
    listQuery.staticTexts["Pre-Trip Checklist"].tap()
    XCTAssertFalse(app.textFields["checklistNameField"].exists, "Tapping a row in Edit mode shouldn't open it.")
    XCTAssertTrue(duplicate.isEnabled)
    duplicate.tap()

    XCTAssertTrue(listQuery.staticTexts["Morning Routine copy"].waitForExistence(timeout: 5))
    XCTAssertTrue(listQuery.staticTexts["Pre-Trip Checklist copy"].exists)
    XCTAssertFalse(listQuery.staticTexts["Weekend Getaway Essentials copy"].exists, "Only the selection is copied.")
    XCTAssertTrue(app.buttons["toolbar.addChecklist"].waitForExistence(timeout: 5), "The action should end Edit mode.")
    XCTAssertFalse(duplicate.exists)
  }

  func testEditModeDeletesSelectionAfterConfirming() {
    let listQuery = app.collectionViews
    enterEditMode()
    listQuery.staticTexts["Weekend Getaway Essentials"].tap()
    app.buttons["editBar.delete"].tap()

    let confirmDelete = app.alerts.buttons["Delete"]
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete confirmation alert didn't appear.")
    confirmDelete.tap()

    XCTAssertTrue(listQuery.staticTexts["Morning Routine"].waitForExistence(timeout: 5))
    XCTAssertFalse(listQuery.staticTexts["Weekend Getaway Essentials"].exists)
    XCTAssertTrue(listQuery.staticTexts["Pre-Trip Checklist"].exists)
  }

  func testResetAllAsksFirst() {
    let resetAll = app.buttons["toolbar.resetAll"]
    XCTAssertTrue(resetAll.waitForExistence(timeout: 5), "Reset All should be in the nav bar.")
    resetAll.tap()
    let cancel = app.alerts.buttons["Cancel"]
    XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Reset All should confirm first.")
    cancel.tap()
  }

  /// The bar draws no title, but VoiceOver still needs to hear which screen this is.
  func testListIsNamedForVoiceOver() {
    XCTAssertTrue(app.navigationBars["Checklists"].exists, "The list's title should be in the accessibility tree.")
  }

  /// An icon that isn't decorative is an image element named after its asset, "MainMenuFeedbackIcon".
  func testMenuRowsReadOnlyTheirNames() {
    app.buttons["toolbar.mainMenu"].tap()
    for title in ["Feedback", "Rate in App Store", "Settings"] {
      XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5), "The \(title) row should be labelled with its name alone.")
    }
    for asset in ["MainMenuFeedbackIcon", "MainMenuRateInAppStoreIcon", "MainMenuSettingsIcon"] {
      XCTAssertFalse(app.images[asset].exists, "The \(asset) icon should be decorative.")
    }
  }

  /// It leaves the app for a web page, so VoiceOver should call it a link, not a button.
  func testPrivacyPolicyIsALink() {
    app.buttons["toolbar.mainMenu"].tap()
    app.buttons["mainMenu.settings"].tap()
    XCTAssertTrue(app.links["Privacy Policy"].waitForExistence(timeout: 5), "Privacy Policy should be a link.")
    XCTAssertFalse(app.buttons["Privacy Policy"].exists, "Privacy Policy shouldn't also be a button.")
  }

  private func enterEditMode() {
    let edit = app.buttons["toolbar.edit"]
    XCTAssertTrue(edit.waitForExistence(timeout: 5), "The Edit button didn't appear.")
    edit.tap()
  }
}
