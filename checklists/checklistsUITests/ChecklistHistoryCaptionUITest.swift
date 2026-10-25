//
//  ChecklistHistoryCaptionUITest.swift
//  checklistsUITests
//
//  Created by Jimmy Ho on 12/31/20.
//

import XCTest

/// The detail screen's caption: when the checklist was last updated and last completed.
final class ChecklistHistoryCaptionUITest: ChecklistDetailUITestCase {
  /// A checklist with no history still shows both caption lines, reading "Never".
  func testHistoryCaptionReadsNeverOnFreshChecklist() {
    // Every UI-test launch gets a freshly seeded in-memory store, so nothing has been ticked yet.
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    let caption = app.staticTexts["checklistMetadataLabel"]
    XCTAssertTrue(caption.waitForExistence(timeout: 5))
    XCTAssertEqual(caption.label, "Last updated: Never. Last completed: Never")
  }

  /// The create sheet shows no caption: there, both lines could only ever read "Never".
  func testHistoryCaptionAbsentOnNewChecklistSheet() {
    app.buttons["Add new checklist."].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    XCTAssertFalse(
      app.staticTexts["checklistMetadataLabel"].exists,
      "The create sheet should not carry a caption that can only say Never.",
    )
  }

  /// Ticking an item rewrites the caption without leaving the screen.
  func testHistoryCaptionUpdatesWhileOnScreen() {
    checklistsList.staticTexts["Morning Routine"].tap()
    let tablesQuery = app.tables
    XCTAssertTrue(tablesQuery["ChecklistTableView"].waitForExistence(timeout: 5))

    let caption = app.staticTexts["checklistMetadataLabel"]
    XCTAssertTrue(caption.waitForExistence(timeout: 5))
    XCTAssertTrue(caption.label.hasPrefix("Last updated: Never"))

    tablesQuery.children(matching: .cell).element(boundBy: 0).buttons["itemCheckbox"].tap()

    // An expectation rather than reading `.label` straight after the tap: a bare read forces a
    // snapshot that blocks until the app goes idle, with no deadline of its own.
    let captionChanged = expectation(
      for: NSPredicate(format: "NOT (label BEGINSWITH %@)", "Last updated: Never"),
      evaluatedWith: caption,
    )
    captionChanged.expectationDescription = "the caption tracks a tick live, without reopening the screen"
    wait(for: [captionChanged], timeout: 5)
  }

  /**
   1. Complete "Morning Routine" by checking its one remaining item.
   2. Leave and come back, so the caption is rebuilt from the store rather than refreshed in place.
   3. Verify both lines are there.
   4. Reset, leave and come back again: the completion line outlives the reset.
   */
  @MainActor func testHistoryCaptionAfterCompletingAndResetting() {
    checklistsList.staticTexts["Morning Routine"].tap()
    let tablesQuery = app.tables
    XCTAssertTrue(tablesQuery["ChecklistTableView"].waitForExistence(timeout: 5))

    // Tap every unchecked box rather than a hardcoded row, so the test survives a fixture change.
    // Each tap waits to land before the next row is looked up by index; see
    // `ChecklistItemsUITest.testCheckboxesAndReset`.
    let cells = tablesQuery.children(matching: .cell)
    for index in 0 ..< cells.count {
      let checkbox = cells.element(boundBy: index).buttons["itemCheckbox"]
      if checkbox.exists, !checkbox.isSelected {
        checkbox.tap()
        XCTAssertTrue(checkbox.wait(for: \.isSelected, toEqual: true, timeout: 5), "Row \(index) didn't check.")
      }
    }

    detailBackButton.tap()
    checklistsList.staticTexts["Morning Routine"].tap()

    let caption = app.staticTexts["checklistMetadataLabel"]
    XCTAssertTrue(caption.waitForExistence(timeout: 5), "A completed checklist should show a caption.")
    // The label reads as two sentences; the dates themselves follow the runner's locale, so only
    // the prefixes are asserted.
    XCTAssertTrue(caption.label.hasPrefix("Last updated: "), "Unexpected caption: \(caption.label)")
    XCTAssertTrue(caption.label.contains("Last completed: "), "Unexpected caption: \(caption.label)")
    XCTAssertFalse(caption.label.hasSuffix("Never"), "Unexpected caption: \(caption.label)")

    app.navigationBars.buttons["checklist.reset"].tap()
    detailBackButton.tap()
    checklistsList.staticTexts["Morning Routine"].tap()

    let captionAfterReset = app.staticTexts["checklistMetadataLabel"]
    XCTAssertTrue(captionAfterReset.waitForExistence(timeout: 5))
    XCTAssertTrue(
      captionAfterReset.label.contains("Last completed: "),
      "Reset clears the checkmarks, not the record that a run finished. Got: \(captionAfterReset.label)",
    )
    XCTAssertFalse(
      captionAfterReset.label.hasSuffix("Never"),
      "Reset must not erase the completion date. Got: \(captionAfterReset.label)",
    )
  }
}
