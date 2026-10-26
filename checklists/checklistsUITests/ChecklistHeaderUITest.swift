//
//  ChecklistHeaderUITest.swift
//  checklistsUITests
//
//  Created by Jimmy Ho on 12/31/20.
//

import XCTest

private let loremIspum = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
  + "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. "
  + "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. "
  + "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

/// The checklist's name and notes, edited on the detail screen and shown on the main list.
final class ChecklistHeaderUITest: ChecklistDetailUITestCase {
  /**
   1. Go to the "Morning Routine" Checklist.
   2. Edit Checklist Name to "Morning Ritual"
   3. Add Checklist Notes to empty notes.
   4. Go back to main page and check that text was updated.
   5. Tap back into that same Checklist and check that stuff is still updated.
   */
  func testEditHeaderInfo() {
    let newChecklistName = "Morning Ritual"
    let newChecklistNotes = "Do this mindfully!!!"

    checklistsList.staticTexts["Morning Routine"].tap()

    let tablesQuery = app.tables
    let checklistNameField = tablesQuery.textFields["Checklist Name: "]
    XCTAssertTrue(checklistNameField.waitForExistence(timeout: 5))
    checklistNameField.tapForKeyboardFocus()
    checklistNameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
    checklistNameField.typeText("Ritual")

    let checklistNotesTextView = tablesQuery.textViews["Checklist Notes: "]
    checklistNotesTextView.tap()
    checklistNotesTextView.typeText(newChecklistNotes)

    detailBackButton.tap()
    // The main list's notes preview label has an explicit accessibilityIdentifier
    // ("checklistNotesLabel", set on every row), so it no longer matches by its rendered text via the
    // bare `staticTexts[...]` subscript the way an unlabeled element would — look it up by identifier
    // and assert on its `.label` instead.
    let morningRoutineNotesLabel = checklistsList.cells.element(boundBy: 0).staticTexts["checklistNotesLabel"]
    XCTAssert(app.staticTexts[newChecklistName].exists)
    XCTAssertTrue(morningRoutineNotesLabel.waitForExistence(timeout: 5), "Notes label didn't appear on the main list after the pop-back animation.")
    XCTAssertEqual(morningRoutineNotesLabel.label, newChecklistNotes)

    app.staticTexts[newChecklistName].tap()
    // Back on the detail screen, the name is rendered in a text field, not a static text (the
    // static-text check above only made sense on the main list) — check the field's value instead.
    let checklistNameFieldAfterReentry = app.tables["ChecklistTableView"].textFields["checklistNameField"]
    let checklistNotesTextViewAfterReentry = app.tables["ChecklistTableView"].textViews["checklistNotesTextView"]
    XCTAssertTrue(checklistNameFieldAfterReentry.waitForExistence(timeout: 5))
    XCTAssertEqual(checklistNameFieldAfterReentry.value as? String, newChecklistName)
    XCTAssertEqual(checklistNotesTextViewAfterReentry.value as? String, newChecklistNotes)
  }

  func testLongChecklistNotesWithScrolling() {
    checklistsList.staticTexts["Weekend Getaway Essentials"].tap()

    let checklistTableView = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTableView.waitForExistence(timeout: 5))
    let checklistnotestextviewTextView = checklistTableView.textViews["checklistNotesTextView"]
    checklistnotestextviewTextView.tapForKeyboardFocus()

    let notes = loremIspum + "\n" + loremIspum
    app.typeText(notes)

    app.tapChecklistEditingDone()

    checklistTableView.swipeUp()

    detailBackButton.tap()

    let weekendGetawayNotesLabel = checklistsList.cells.element(boundBy: 1).staticTexts["checklistNotesLabel"]
    XCTAssertTrue(weekendGetawayNotesLabel.waitForExistence(timeout: 5), "Notes label didn't appear on the main list after the pop-back animation.")
    XCTAssert(weekendGetawayNotesLabel.label.starts(with: notes.prefix(15)))
  }

  /// Long notes must not push the list underneath the header.
  ///
  /// Backing out and re-entering is the point: typing grows the header through `textViewDidChange`,
  /// so this only shows on a screen that opens with long notes already saved.
  func testLongNotesDoNotCoverTheFirstItem() {
    checklistsList.staticTexts["Morning Routine"].tap()
    let tablesQuery = app.tables
    XCTAssertTrue(tablesQuery["ChecklistTableView"].waitForExistence(timeout: 5))

    tablesQuery.textViews["checklistNotesTextView"].tapForKeyboardFocus()
    app.typeText((1 ... 6).map { "Notes line \($0)." }.joined(separator: "\n"))
    app.tapChecklistEditingDone()

    detailBackButton.tap()
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(tablesQuery["ChecklistTableView"].waitForExistence(timeout: 5))

    let firstCheckbox = tablesQuery.children(matching: .cell).element(boundBy: 0).buttons["itemCheckbox"]
    XCTAssertTrue(firstCheckbox.waitForExistence(timeout: 5))
    XCTAssertTrue(firstCheckbox.isHittable, "The first item is sitting underneath the header.")
  }
}
