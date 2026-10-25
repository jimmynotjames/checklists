//
//  ChecklistMoveAndDeleteCheckedItemsUITest.swift
//  checklistsUITests
//

import XCTest

/// The detail screen's "Move Checked Items to…" and "Delete Checked Items" entries.
///
/// Beside `ChecklistCopyCheckedItemsUITest` rather than in it: Move shares Copy's picker, which that
/// file already covers, so what is left here is what each entry takes out of the source.
class ChecklistMoveAndDeleteCheckedItemsUITest: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["-UITests1"]
    app.launch()
    XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5), "Main checklists list did not appear after launch.")
  }

  override func tearDownWithError() throws {}

  /// See `ChecklistDetailUITestCase.checklistsList`.
  private var checklistsList: XCUIElementQuery {
    app.collectionViews
  }

  private var detailBackButton: XCUIElement {
    app.navigationBars.buttons["BackButton"]
  }

  // MARK: - Helpers

  /// See `ChecklistCopyCheckedItemsUITest.morningRoutineChecklistId`.
  private static let morningRoutineChecklistId = "C4EC1157-0000-4000-A000-000000000001"

  /// See `ChecklistCopyCheckedItemsUITest.itemNames(in:)`.
  private func itemNames(in table: XCUIElement) -> [String] {
    let cells = table.children(matching: .cell)
    return (0 ..< cells.count).compactMap {
      cells.element(boundBy: $0).textViews["itemNameTextView"].value as? String
    }
  }

  /// Opens the detail screen's overflow menu and taps the entry with `identifier`.
  private func tapMenuEntry(_ identifier: String) {
    let moreButton = app.navigationBars.buttons["checklist.more"]
    XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "Overflow menu button didn't appear.")
    moreButton.tap()
    let entry = app.buttons[identifier]
    XCTAssertTrue(entry.waitForExistence(timeout: 5), "Menu entry \(identifier) didn't appear.")
    entry.tap()
  }

  // MARK: - Move

  /// The moved item leaves the source at once, with the picker gone and the person still on it.
  func testMoveCheckedItemsToAnExistingChecklist() {
    // Pre-Trip Checklist is seeded with none of its items checked.
    checklistsList.staticTexts["Pre-Trip Checklist"].tap()
    let preTripTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(preTripTable.waitForExistence(timeout: 5))
    let namesBefore = itemNames(in: preTripTable)
    preTripTable.children(matching: .cell).element(boundBy: 0).buttons["itemCheckbox"].tap()

    tapMenuEntry("checklist.menu.moveCheckedItems")

    let destination = app.buttons["copyDestination.\(Self.morningRoutineChecklistId)"]
    XCTAssertTrue(destination.waitForExistence(timeout: 5), "The destination picker didn't list Morning Routine.")
    destination.tap()

    // Looked for first: a toast stays up only briefly, and waiting out the sheet's slide-away
    // before querying can let it go. By label, and of any element type: the card's `toast`
    // identifier is what a subscript would match first, and SwiftUI decides how the text surfaces.
    let toast = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS %@", "Moved items to Morning Routine")).firstMatch
    XCTAssertTrue(toast.waitForExistence(timeout: 5), "The toast didn't appear.")
    XCTAssertFalse(destination.exists, "The picker didn't dismiss.")
    XCTAssertEqual(
      itemNames(in: preTripTable),
      Array(namesBefore.dropFirst()),
      "The moved item should be gone from the source without leaving the screen.",
    )

    detailBackButton.tap()
    checklistsList.staticTexts["Morning Routine"].tap()
    let morningTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(morningTable.waitForExistence(timeout: 5))
    XCTAssertEqual(itemNames(in: morningTable).last, namesBefore.first, "The moved item should sit at the end.")
  }

  // MARK: - Delete

  /// Morning Routine is seeded with five of its six items checked; "Journaling" is the one that isn't.
  func testDeleteCheckedItemsConfirmsThenKeepsTheUnchecked() {
    checklistsList.staticTexts["Morning Routine"].tap()
    let table = app.tables["ChecklistTableView"]
    XCTAssertTrue(table.waitForExistence(timeout: 5))

    // Cancel first: nothing goes.
    tapMenuEntry("checklist.menu.deleteCheckedItems")
    let cancel = app.alerts.buttons["Cancel"]
    XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Deleting checked items should ask first.")
    XCTAssertTrue(
      app.alerts.staticTexts["Delete 5 checked items? This cannot be undone."].exists,
      "The confirmation should say how many items will go.",
    )
    cancel.tap()
    XCTAssertEqual(itemNames(in: table).count, 6)

    // Then confirm: only the unchecked item is left.
    tapMenuEntry("checklist.menu.deleteCheckedItems")
    let confirmDelete = app.alerts.buttons["Delete"]
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
    confirmDelete.tap()
    XCTAssertEqual(itemNames(in: table), ["Journaling"])
  }

  // MARK: - Nothing checked

  /// The same rule the copy entry teaches, under each entry that acts on checked items.
  func testMoveAndDeleteEntriesExplainThemselvesWithNothingChecked() {
    checklistsList.staticTexts["Pre-Trip Checklist"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    for identifier in ["checklist.menu.moveCheckedItems", "checklist.menu.deleteCheckedItems"] {
      tapMenuEntry(identifier)
      // Checked at once, not waited for; `ChecklistCopyCheckedItemsUITest` says why.
      XCTAssertTrue(app.buttons["No checked items."].exists, "No notice under \(identifier).")
      XCTAssertFalse(app.alerts.firstMatch.exists, "With nothing checked there is nothing to confirm.")
      XCTAssertFalse(
        app.buttons["copyDestination.createNewChecklist"].exists,
        "With nothing checked there is nothing to pick a destination for.",
      )
      // Closes the menu, which stayed up to show the notice, before the next entry is tried. Waits
      // on the entry, not the notice: the notice also leaves on its own timer with the menu still
      // up, and the next overflow tap would then land on Reorder Items, which covers the button.
      app.tables["ChecklistTableView"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
      XCTAssertTrue(app.buttons[identifier].waitForNonExistence(timeout: 5), "The menu didn't close.")
    }
  }
}
