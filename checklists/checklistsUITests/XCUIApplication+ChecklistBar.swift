//
//  XCUIApplication+ChecklistBar.swift
//  checklistsUITests
//

import XCTest

/// Opening and closing the create sheet, and the checklist screen's navigation-bar buttons that come
/// and go with typing. Bar buttons are matched by identifier, without naming the bar: see
/// `ChecklistDetailUITestCase.detailBackButton`.
///
/// While a field on an existing checklist is being typed into, the editing Done sits at the bar's
/// outer edge. The create sheet never shows it: its own Done stays there and closes the sheet even
/// mid-typing, so a test on the create sheet keeps the keyboard up until it finishes.
extension XCUIApplication {
  /// Ends typing on the checklist screen.
  var checklistEditingDoneButton: XCUIElement {
    navigationBars.buttons["checklist.editingDone"]
  }

  /// Closes the create sheet, whether or not anything is being typed.
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

  /// Closes the create sheet with one tap on its Done, which also keeps whatever is being typed.
  func finishCreateSheet(file: StaticString = #filePath, line: UInt = #line) {
    let button = createSheetDoneButton
    XCTAssertTrue(button.waitForExistence(timeout: 5), "The create sheet's Done isn't in the bar.", file: file, line: line)
    button.tap()
  }

  /// Taps the checklists list's add button — in the bottom toolbar, not a row inside the list, so it
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
