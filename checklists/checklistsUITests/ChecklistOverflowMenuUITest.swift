//
//  ChecklistOverflowMenuUITest.swift
//  checklistsUITests
//
//  Created by Jimmy Ho on 12/31/20.
//

import XCTest

/// The detail screen's overflow menu: duplicating, discarding the copy, and deleting.
final class ChecklistOverflowMenuUITest: ChecklistDetailUITestCase {
  // MARK: - Duplicating from the overflow menu

  /// The sheet the copy opens in. Two navigation bars are in the tree once it is up, and only this
  /// one carries Done — the pushed screen behind it carries Reset.
  private var duplicateSheetNavigationBar: XCUIElement {
    app.navigationBars.containing(.button, identifier: "Done").firstMatch
  }

  private func tapDuplicateChecklistEntry() {
    let moreButton = app.navigationBars.buttons["checklist.more"]
    XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "Overflow menu button didn't appear.")
    moreButton.tap()
    // A `UIMenu` entry surfaces as a loose button rather than inside the navigation bar.
    let duplicateEntry = app.buttons["Duplicate Checklist"]
    XCTAssertTrue(duplicateEntry.waitForExistence(timeout: 5), "Duplicate Checklist menu entry didn't appear.")
    duplicateEntry.tap()
  }

  /// The name the open sheet is showing, read across both `checklistNameField`s in the tree: the
  /// pushed screen behind the sheet still has one.
  private func visibleChecklistNames() -> [String] {
    let fields = app.textFields.matching(identifier: "checklistNameField")
    return (0 ..< fields.count).compactMap { fields.element(boundBy: $0).value as? String }
  }

  /// Duplicating opens the copy in the create sheet rather than navigating, so that renaming it is
  /// the next thing the keyboard is already waiting for.
  func testDuplicateChecklistFromDetailMenu() {
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    tapDuplicateChecklistEntry()

    XCTAssertTrue(duplicateSheetNavigationBar.waitForExistence(timeout: 5), "The copy's sheet didn't appear.")
    // Unconfirmed: the sheet is the only thing between the tap and the copy.
    XCTAssertFalse(app.alerts.firstMatch.exists, "Duplicating shouldn't raise a confirmation.")
    XCTAssertTrue(
      visibleChecklistNames().contains("Morning Routine copy"),
      "The sheet should be showing the copy, named after the original."
    )

    duplicateSheetNavigationBar.buttons["Done"].tap()

    // Done lands back on the original, which is where the duplication was started from.
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))
    detailBackButton.tap()
    XCTAssertTrue(checklistsList.staticTexts["Morning Routine copy"].waitForExistence(timeout: 5))
    XCTAssertTrue(checklistsList.staticTexts["Morning Routine"].exists, "The original should still be in the list.")
  }

  /// Discard is the way back out of an accidental duplicate, and the reason the copy opens in the
  /// create sheet rather than as a push.
  func testDiscardingADuplicateRemovesIt() {
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    tapDuplicateChecklistEntry()
    XCTAssertTrue(duplicateSheetNavigationBar.waitForExistence(timeout: 5), "The copy's sheet didn't appear.")

    duplicateSheetNavigationBar.buttons["checklist.more"].tap()
    let discardEntry = app.buttons["Discard Checklist"]
    XCTAssertTrue(discardEntry.waitForExistence(timeout: 5), "Discard Checklist menu entry didn't appear.")
    discardEntry.tap()
    let confirmDiscard = app.alerts.buttons["Discard"]
    XCTAssertTrue(confirmDiscard.waitForExistence(timeout: 5), "Discard confirmation alert didn't appear.")
    confirmDiscard.tap()

    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))
    detailBackButton.tap()
    XCTAssertTrue(checklistsList.staticTexts["Morning Routine"].waitForExistence(timeout: 5))
    XCTAssertFalse(checklistsList.staticTexts["Morning Routine copy"].exists, "The discarded copy should be gone.")
  }

  // MARK: - Deleting from the overflow menu

  /// Opens the detail screen's overflow menu and taps Delete Checklist, leaving the
  /// confirmation up.
  private func tapDeleteChecklistEntry() {
    let moreButton = app.navigationBars.buttons["checklist.more"]
    XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "Overflow menu button didn't appear.")
    moreButton.tap()
    // A `UIMenu` entry surfaces as a loose button rather than inside the navigation bar.
    let deleteEntry = app.buttons["Delete Checklist"]
    XCTAssertTrue(deleteEntry.waitForExistence(timeout: 5), "Delete Checklist menu entry didn't appear.")
    deleteEntry.tap()
  }

  func testDeleteChecklistFromDetailMenu() {
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    tapDeleteChecklistEntry()
    let confirmDelete = app.alerts.buttons["Delete"]
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete confirmation alert didn't appear.")
    confirmDelete.tap()

    // Both halves of the delete: the screen goes away *and* the row is gone from the list behind it.
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForNonExistence(timeout: 5), "The detail screen didn't dismiss.")
    XCTAssertTrue(checklistsList.staticTexts["Pre-Trip Checklist"].waitForExistence(timeout: 5))
    XCTAssertFalse(checklistsList.staticTexts["Morning Routine"].exists)
  }

  func testCancellingDeleteKeepsTheChecklist() {
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    tapDeleteChecklistEntry()
    let cancel = app.alerts.buttons["Cancel"]
    XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Delete confirmation alert didn't appear.")
    cancel.tap()

    XCTAssertTrue(app.tables["ChecklistTableView"].exists, "Cancelling should leave the screen up.")
    detailBackButton.tap()
    XCTAssertTrue(checklistsList.staticTexts["Morning Routine"].waitForExistence(timeout: 5))
  }

  /// Deleting straight out of an active edit, with the keyboard still up. The name field's delegate
  /// writes on resignation, so this is the case that catches a commit landing after the record is
  /// gone — and the trailing-blank-item trim that runs once the screen has left.
  func testDeleteChecklistWhileEditingItsName() {
    checklistsList.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTableView.waitForExistence(timeout: 5))

    let nameField = checklistTableView.textFields["checklistNameField"]
    nameField.tap()
    app.typeText(" edited")

    tapDeleteChecklistEntry()
    let confirmDelete = app.alerts.buttons["Delete"]
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete confirmation alert didn't appear.")
    confirmDelete.tap()

    XCTAssertTrue(checklistsList.staticTexts["Pre-Trip Checklist"].waitForExistence(timeout: 5))
    XCTAssertFalse(checklistsList.staticTexts["Morning Routine"].exists)
    XCTAssertFalse(checklistsList.staticTexts["Morning Routine edited"].exists)
  }
}
