//
//  ChecklistExportPDFUITest.swift
//  checklistsUITests
//

import XCTest

/// The checklist menu's Export as PDF…: where it is offered, and that it goes straight to the share
/// sheet. The share sheet itself is the system's and is not driven past opening.
final class ChecklistExportPDFUITest: ChecklistDetailUITestCase {
  func testExportOpensTheShareSheet() {
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))
    let moreButton = app.navigationBars.buttons["checklist.more"]
    XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "Overflow menu button didn't appear.")
    moreButton.tap()
    let exportEntry = app.buttons["checklist.menu.exportPDF"]
    XCTAssertTrue(exportEntry.waitForExistence(timeout: 5), "Export as PDF… menu entry didn't appear.")
    exportEntry.tap()

    let shareSheet = app.otherElements["ActivityListView"]
    XCTAssertTrue(shareSheet.waitForExistence(timeout: 10), "The share sheet didn't open.")
  }

  func testCreateSheetMenuHasNoExportEntry() {
    app.buttons["Add new checklist."].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5), "The create sheet didn't open.")

    let moreButton = app.navigationBars.buttons["checklist.more"]
    XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "Overflow menu button didn't appear.")
    moreButton.tap()

    XCTAssertTrue(app.buttons["checklist.menu.reorderItems"].waitForExistence(timeout: 5), "The overflow menu didn't open.")
    XCTAssertFalse(app.buttons["checklist.menu.exportPDF"].exists, "The create sheet shouldn't offer Export as PDF….")
  }
}
