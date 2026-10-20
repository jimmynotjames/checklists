//
//  XCUIApplication+ChecklistBar.swift
//  checklistsUITests
//

import XCTest

/// The checklist screen's navigation-bar buttons that come and go with typing. Matched by
/// identifier, without naming the bar: see `ChecklistDetailUITestCase.detailBackButton`.
///
/// While a field is being typed into, the editing Done takes the slot beside the overflow menu, and
/// it reads "Done" just as the create sheet's own Done does, so a `buttons["Done"]` query matches
/// whichever of the two is showing.
extension XCUIApplication {
  /// Ends typing on the checklist screen.
  var checklistEditingDoneButton: XCUIElement {
    navigationBars.buttons["checklist.editingDone"]
  }

  /// Closes the create sheet. Only there while nothing is being typed.
  var createSheetDoneButton: XCUIElement {
    navigationBars.buttons["checklist.done"]
  }

  /// Taps the editing Done and waits for the bar to hand its slot back.
  func tapChecklistEditingDone(file: StaticString = #filePath, line: UInt = #line) {
    let button = checklistEditingDoneButton
    XCTAssertTrue(button.waitForExistence(timeout: 5), "The editing Done isn't in the bar.", file: file, line: line)
    button.tap()
    XCTAssertTrue(button.waitForNonExistence(timeout: 5), "The editing Done stayed after ending editing.", file: file, line: line)
  }

  /// Ends any typing, then closes the create sheet: two taps, since while typing the slot holds the
  /// editing Done instead.
  func finishCreateSheet(file: StaticString = #filePath, line: UInt = #line) {
    if checklistEditingDoneButton.exists {
      tapChecklistEditingDone(file: file, line: line)
    }
    let button = createSheetDoneButton
    XCTAssertTrue(button.waitForExistence(timeout: 5), "The create sheet's Done isn't in the bar.", file: file, line: line)
    button.tap()
  }
}
