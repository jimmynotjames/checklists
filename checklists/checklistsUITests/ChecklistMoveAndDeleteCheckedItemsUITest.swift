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
    app.configureForUITests()
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

  /// The create sheet the picker's New Checklist opens on top of the source's screen. Both show a
  /// `ChecklistTableView`, so it is the one whose name field isn't the source's.
  private func createSheetTable(sourceName: String) -> XCUIElement {
    app.tables.matching(identifier: "ChecklistTableView")
      .containing(NSPredicate(format: "identifier == 'checklistNameField' AND NOT (value == %@)", sourceName))
      .firstMatch
  }

  /// Opens Move's New Checklist and waits for the create sheet to focus its name field.
  private func openNewChecklistForMove() {
    tapMenuEntry("checklist.menu.moveCheckedItems")
    let newChecklist = app.buttons["copyDestination.newChecklist"]
    XCTAssertTrue(newChecklist.waitForExistence(timeout: 5), "The destination picker didn't appear.")
    newChecklist.tap()
    // See `ChecklistCopyCheckedItemsUITest.openNewChecklistFromPicker`: only the sheet's name field
    // can have focus.
    let focusedName = app.textFields.matching(
      NSPredicate(format: "identifier == 'checklistNameField' AND hasKeyboardFocus == true"),
    ).firstMatch
    XCTAssertTrue(focusedName.waitForExistence(timeout: 10), "The create sheet's name field never took focus.")
  }

  /// Nothing leaves the source while the create sheet is up; Done is what takes it.
  func testMoveCheckedItemsToANewChecklistOnDone() {
    checklistsList.staticTexts["Pre-Trip Checklist"].tap()
    let preTripTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(preTripTable.waitForExistence(timeout: 5))
    let namesBefore = itemNames(in: preTripTable)
    preTripTable.children(matching: .cell).element(boundBy: 0).buttons["itemCheckbox"].tap()

    openNewChecklistForMove()
    let sheetTable = createSheetTable(sourceName: "Pre-Trip Checklist")
    XCTAssertTrue(sheetTable.waitForExistence(timeout: 5), "The create sheet's checklist didn't appear.")
    XCTAssertEqual(itemNames(in: sheetTable), [namesBefore[0]], "The create sheet should open on the copied item.")
    app.typeText("Ferry Day")
    app.finishCreateSheet()

    let toast = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS %@", "Moved items to Ferry Day")).firstMatch
    XCTAssertTrue(toast.waitForExistence(timeout: 5), "The toast didn't appear.")
    // The toast rises as the sheet starts to slide away, while its table is still in the tree.
    XCTAssertTrue(sheetTable.waitForNonExistence(timeout: 5), "The create sheet didn't close.")
    XCTAssertEqual(
      itemNames(in: preTripTable),
      Array(namesBefore.dropFirst()),
      "Keeping the new checklist should take the moved item out of the source.",
    )
  }

  /// Discard undoes the whole move, whatever was changed on the create sheet first: the source
  /// keeps every checked item, under its own name and still ticked.
  func testDiscardingAMoveAfterEditsLeavesTheSource() {
    // Morning Routine is seeded with five of its six items checked; "Journaling" is the one that isn't.
    checklistsList.staticTexts["Morning Routine"].tap()
    let sourceTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(sourceTable.waitForExistence(timeout: 5))
    let namesBefore = itemNames(in: sourceTable)

    openNewChecklistForMove()
    let sheetTable = createSheetTable(sourceName: "Morning Routine")
    XCTAssertTrue(sheetTable.waitForExistence(timeout: 5), "The create sheet's checklist didn't appear.")

    // Rename the first copy, then delete the second. The sheet's name field has the keyboard as it
    // opens, and typing keeps it up throughout: the create sheet's bar has no editing Done.
    let firstName = sheetTable.children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"]
    firstName.tapForKeyboardFocus(at: CGVector(dx: 0.9, dy: 0.9))
    firstName.typeText(" edited")
    sheetTable.children(matching: .cell).element(boundBy: 1).swipeLeft()
    let deleteAction = sheetTable.buttons["Delete"]
    XCTAssertTrue(deleteAction.waitForExistence(timeout: 5), "Swipe-to-delete action didn't appear.")
    deleteAction.tap()

    let moreButton = app.navigationBars.containing(
      NSPredicate(format: "identifier == 'checklist.done'"),
    ).firstMatch.buttons["checklist.more"]
    XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "The create sheet's overflow menu button didn't appear.")
    moreButton.tap()
    let discardEntry = app.buttons["Discard Checklist"]
    XCTAssertTrue(discardEntry.waitForExistence(timeout: 5), "Discard Checklist menu entry didn't appear.")
    discardEntry.tap()
    let confirmDiscard = app.alerts.buttons["Discard"]
    XCTAssertTrue(confirmDiscard.waitForExistence(timeout: 5), "Discard confirmation alert didn't appear.")
    confirmDiscard.tap()

    XCTAssertTrue(sheetTable.waitForNonExistence(timeout: 5), "The create sheet didn't close.")
    XCTAssertEqual(itemNames(in: sourceTable), namesBefore, "Discard should leave every original in the source.")
    let checkedCount = (0 ..< sourceTable.cells.count)
      .count { sourceTable.cells.element(boundBy: $0).buttons["itemCheckbox"].isSelected }
    XCTAssertEqual(checkedCount, 5, "The originals should still be ticked.")
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

  /// The same rule the copy entry teaches, for each entry that acts on checked items.
  func testMoveAndDeleteEntriesExplainThemselvesWithNothingChecked() {
    checklistsList.staticTexts["Pre-Trip Checklist"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    for identifier in ["checklist.menu.moveCheckedItems", "checklist.menu.deleteCheckedItems"] {
      tapMenuEntry(identifier)
      XCTAssertTrue(noCheckedItemsToast.waitForExistence(timeout: 5), "No toast for \(identifier).")
      XCTAssertFalse(app.alerts.firstMatch.exists, "With nothing checked there is nothing to confirm.")
      XCTAssertFalse(
        app.buttons["copyDestination.newChecklist"].exists,
        "With nothing checked there is nothing to pick a destination for.",
      )
      XCTAssertTrue(app.buttons[identifier].waitForNonExistence(timeout: 5), "The menu didn't close.")
      // Gone before the next entry is tried, so its toast is its own and not this one's.
      XCTAssertTrue(noCheckedItemsToast.waitForNonExistence(timeout: 10), "The toast didn't go.")
    }
  }

  /// By label, and of any element type, as the move toast above is found.
  private var noCheckedItemsToast: XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "No checked items.")).firstMatch
  }
}
