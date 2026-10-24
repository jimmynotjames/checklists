//
//  ChecklistExportPDFUITest.swift
//  checklistsUITests
//

import XCTest

/// The checklist menu's Export as PDF…: where it is offered, and the export sheet's Saved Headers.
/// The share sheet itself is the system's and is not driven here.
final class ChecklistExportPDFUITest: ChecklistDetailUITestCase {
  private var headerField: XCUIElement {
    app.textViews["exportPDF.header"]
  }

  private var savedHeadersMenu: XCUIElement {
    app.buttons["exportPDF.savedHeaders"]
  }

  private var saveForReuseButton: XCUIElement {
    app.buttons["exportPDF.saveForReuse"]
  }

  private func openExportSheet() {
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))
    let moreButton = app.navigationBars.buttons["checklist.more"]
    XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "Overflow menu button didn't appear.")
    moreButton.tap()
    let exportEntry = app.buttons["checklist.menu.exportPDF"]
    XCTAssertTrue(exportEntry.waitForExistence(timeout: 5), "Export as PDF… menu entry didn't appear.")
    exportEntry.tap()
    XCTAssertTrue(headerField.waitForExistence(timeout: 5), "The export sheet didn't open.")
  }

  func testExportSheetOpensFromTheMenuAndCloses() {
    openExportSheet()

    XCTAssertTrue(app.datePickers["exportPDF.date"].exists || app.otherElements["exportPDF.date"].exists, "No date picker.")
    XCTAssertTrue(app.buttons["exportPDF.export"].exists, "No Export button.")
    XCTAssertEqual(headerField.value as? String ?? "", "", "The Header should start empty.")
    XCTAssertFalse(savedHeadersMenu.exists, "With nothing saved there should be no Saved Headers menu.")
    XCTAssertFalse(saveForReuseButton.exists, "An empty Header has nothing to save.")

    app.navigationBars.buttons["Close"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5), "Close should return to the checklist.")
    XCTAssertFalse(headerField.exists)
  }

  /// Nothing on the create sheet has been kept yet, so there is nothing to hand anyone.
  func testCreateSheetMenuHasNoExportEntry() {
    app.buttons["Add new checklist."].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5), "The create sheet didn't open.")

    app.navigationBars.buttons["checklist.more"].tap()

    XCTAssertTrue(app.buttons["checklist.menu.reorderItems"].waitForExistence(timeout: 5), "The overflow menu didn't open.")
    XCTAssertFalse(app.buttons["checklist.menu.exportPDF"].exists, "The create sheet shouldn't offer Export as PDF….")
  }

  /// Save, insert (which always appends on a new line), and delete a Saved Header.
  func testSavingInsertingAndDeletingASavedHeader() {
    openExportSheet()

    headerField.tap()
    headerField.typeText("Acme Plumbing")
    XCTAssertTrue(saveForReuseButton.waitForExistence(timeout: 5), "Save for Reuse should appear once there is text.")
    saveForReuseButton.tap()

    XCTAssertTrue(savedHeadersMenu.waitForExistence(timeout: 5), "Saving should bring up the Saved Headers menu.")
    XCTAssertFalse(saveForReuseButton.exists, "Text that is already saved has nothing to save.")

    savedHeadersMenu.tap()
    let entry = app.buttons["Acme Plumbing"]
    XCTAssertTrue(entry.waitForExistence(timeout: 5), "The Saved Header should be in the menu.")
    entry.tap()

    XCTAssertEqual(headerField.value as? String, "Acme Plumbing\nAcme Plumbing", "Inserting appends on a new line.")
    XCTAssertTrue(saveForReuseButton.waitForExistence(timeout: 5), "The longer text is new, so it can be saved.")

    savedHeadersMenu.tap()
    let deleteMenu = app.buttons["exportPDF.savedHeaders.delete"]
    XCTAssertTrue(deleteMenu.waitForExistence(timeout: 5), "The Delete submenu should be in the menu.")
    deleteMenu.tap()
    let deleteEntry = app.buttons["Acme Plumbing"]
    XCTAssertTrue(deleteEntry.waitForExistence(timeout: 5), "The Saved Header should be in the Delete submenu.")
    deleteEntry.tap()

    XCTAssertTrue(savedHeadersMenu.waitForNonExistence(timeout: 5), "With nothing saved the menu should go.")
    XCTAssertEqual(headerField.value as? String, "Acme Plumbing\nAcme Plumbing", "Deleting a Saved Header leaves the field alone.")
  }
}
