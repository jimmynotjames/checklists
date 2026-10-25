//
//  XCUIApplication+ChecklistBar.swift
//  checklistsUITests
//

import XCTest

/// Opening and closing the create sheet, and the checklist screen's navigation-bar buttons that come
/// and go with typing. Bar buttons are matched by identifier, without naming the bar: see
/// `ChecklistDetailUITestCase.detailBackButton`.
///
/// While a field is being typed into, the editing Done sits at the bar's outer edge, in place of the
/// create sheet's own Done there. It reads "Done" just as that one does, so a `buttons["Done"]`
/// query matches whichever of the two is showing.
extension XCUIApplication {
  /// Ends typing on the checklist screen.
  var checklistEditingDoneButton: XCUIElement {
    navigationBars.buttons["checklist.editingDone"]
  }

  /// Closes the create sheet. Only there while nothing is being typed.
  var createSheetDoneButton: XCUIElement {
    navigationBars.buttons["checklist.done"]
  }

  /// Taps the editing Done and waits for it to leave the bar.
  func tapChecklistEditingDone(file: StaticString = #filePath, line: UInt = #line) {
    let button = checklistEditingDoneButton
    XCTAssertTrue(button.waitForExistence(timeout: 5), "The editing Done isn't in the bar.", file: file, line: line)
    button.tap()
    XCTAssertTrue(button.waitForNonExistence(timeout: 5), "The editing Done stayed after ending editing.", file: file, line: line)
  }

  /// Ends any typing, then closes the create sheet: two taps, since while typing the editing Done
  /// stands in for the sheet's own at the outer edge.
  ///
  /// Waits for either button first: the sheet focuses its name field once it has appeared, so a
  /// check made too early would see the sheet's Done just before the editing Done replaces it.
  func finishCreateSheet(file: StaticString = #filePath, line: UInt = #line) {
    let eitherDone = navigationBars.buttons.matching(
      NSPredicate(format: "identifier IN %@", ["checklist.done", "checklist.editingDone"]),
    ).firstMatch
    XCTAssertTrue(eitherDone.waitForExistence(timeout: 5), "The create sheet's bar has no Done.", file: file, line: line)
    if checklistEditingDoneButton.exists {
      tapChecklistEditingDone(file: file, line: line)
    }
    let button = createSheetDoneButton
    XCTAssertTrue(button.waitForExistence(timeout: 5), "The create sheet's Done isn't in the bar.", file: file, line: line)
    button.tap()
  }

  /// Taps the checklists list's add button — an `.overlay` on the list, not a row inside it, so it
  /// hangs off the application rather than the collection view — and waits for the create sheet's name field to take
  /// focus, which it does in `viewDidAppear`: typing before then has nowhere to go.
  func openCreateSheet(file: StaticString = #filePath, line: UInt = #line) {
    buttons["Add new checklist."].tap()
    XCTAssertTrue(
      textFields["checklistNameField"].waitForKeyboardFocus(),
      "The create sheet's name field never took focus.",
      file: file,
      line: line,
    )
  }
}
