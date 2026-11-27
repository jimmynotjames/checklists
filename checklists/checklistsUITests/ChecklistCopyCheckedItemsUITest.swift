//
//  ChecklistCopyCheckedItemsUITest.swift
//  checklistsUITests
//

import XCTest

/// The detail screen's "Copy Checked Items to…" entry and the destination picker behind it.
///
/// Navigation-bar buttons are matched without naming the bar — see `ChecklistDetailUITestCase.detailBackButton`
/// for why naming it makes a query depend on scroll position.
class ChecklistCopyCheckedItemsUITest: XCTestCase {
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

  /// The seeded Morning Routine checklist's id, which the destination picker's row for it carries.
  /// Addressed by id rather than by name because the list screen's row of the same name is still in
  /// the tree behind the sheet.
  private static let morningRoutineChecklistId = "C4EC1157-0000-4000-A000-000000000001"

  /// The detail screen's item names, in order.
  ///
  /// Each row's name is an editable `CLTextView`, not a label, so it is read from the field's value
  /// the way `ChecklistItemsUITest` does — `staticTexts` never matches it. The add-item footer is
  /// not a cell, so every cell here is an item.
  private func itemNames(in table: XCUIElement) -> [String] {
    let cells = table.children(matching: .cell)
    return (0 ..< cells.count).compactMap {
      cells.element(boundBy: $0).textViews["itemNameTextView"].value as? String
    }
  }

  /// Opens the detail screen's overflow menu and taps the copy entry, leaving the picker up.
  private func tapCopyCheckedItemsEntry() {
    let moreButton = app.navigationBars.buttons["checklist.more"]
    XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "Overflow menu button didn't appear.")
    moreButton.tap()
    // A `UIMenu` entry surfaces as a loose button rather than inside the navigation bar. The
    // trailing character is a single ellipsis, not three periods.
    let copyEntry = app.buttons["Copy Checked Items to…"]
    XCTAssertTrue(copyEntry.waitForExistence(timeout: 5), "Copy Checked Items menu entry didn't appear.")
    copyEntry.tap()
  }

  /// Taps New Checklist and waits for the create sheet that replaces the picker to focus its name
  /// field, as `openCreateSheet` does for the list's Add button.
  private func openNewChecklistFromPicker() {
    let newChecklist = app.buttons["copyDestination.newChecklist"]
    XCTAssertTrue(newChecklist.waitForExistence(timeout: 5), "The destination picker didn't appear.")
    newChecklist.tap()
    XCTAssertTrue(newChecklist.waitForNonExistence(timeout: 5), "The picker didn't give way to the create sheet.")
    // Either of the two name fields in the tree, the source's behind the sheet and the new one's:
    // only the sheet's can have focus.
    let focusedName = app.textFields.matching(
      NSPredicate(format: "identifier == 'checklistNameField' AND hasKeyboardFocus == true"),
    ).firstMatch
    XCTAssertTrue(focusedName.waitForExistence(timeout: 10), "The create sheet's name field never took focus.")
  }

  /// Morning Routine is seeded with five of its six items checked, so the entry is offered without
  /// having to tick anything first.
  func testCopyCheckedItemsToANewUntitledChecklist() {
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    tapCopyCheckedItemsEntry()
    openNewChecklistFromPicker()
    // Leaving the name blank is legal: the new checklist takes the name an unnamed one carries
    // everywhere else.
    app.finishCreateSheet()

    // Looked for first, as the move tests do: a toast stays up only briefly.
    let toast = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS %@", "Copied items to untitled checklist")).firstMatch
    XCTAssertTrue(toast.waitForExistence(timeout: 5), "The toast didn't appear.")
    // Staying put is the point: closing the create sheet lands back on the source.
    XCTAssertTrue(app.tables["ChecklistTableView"].exists, "The copy shouldn't navigate away from the source.")

    detailBackButton.tap()
    XCTAssertTrue(checklistsList.staticTexts["untitled checklist"].waitForExistence(timeout: 5))
    XCTAssertTrue(
      checklistsList.cells.element(boundBy: 0).staticTexts["untitled checklist"].exists,
      "A checklist made out of a subset goes to the top, where a new checklist goes.",
    )

    // The five checked items came over, in order; "Journaling", the one left unchecked, did not.
    checklistsList.staticTexts["untitled checklist"].tap()
    let copyTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(copyTable.waitForExistence(timeout: 5))
    XCTAssertEqual(itemNames(in: copyTable), [
      "START COFFEE MAKER",
      "Yoga/meditation",
      "Traffic and weather reports",
      "Breakfast",
      "Argue politics on Facebook",
    ])
    XCTAssertFalse(
      copyTable.children(matching: .cell).element(boundBy: 0).buttons["itemCheckbox"].isSelected,
      "Copied items should arrive unchecked.",
    )
  }

  func testCopyCheckedItemsToANamedNewChecklist() {
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    tapCopyCheckedItemsEntry()
    openNewChecklistFromPicker()
    // Return, not just Done: with several copied rows there is no seeded blank row for Return to
    // move on to, as there is on a plain new checklist.
    app.typeText("Ferry Day\n")
    app.finishCreateSheet()

    XCTAssertTrue(app.createSheetDoneButton.waitForNonExistence(timeout: 5), "The create sheet didn't close.")
    detailBackButton.tap()
    XCTAssertTrue(checklistsList.staticTexts["Ferry Day"].waitForExistence(timeout: 5))
  }

  /// The items land at the end of the destination, which is where items normally arrive.
  func testCopyCheckedItemsToAnExistingChecklist() {
    checklistsList.staticTexts["Pre-Trip Checklist"].tap()
    let preTripTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(preTripTable.waitForExistence(timeout: 5))
    preTripTable.children(matching: .cell).element(boundBy: 0).buttons["itemCheckbox"].tap()

    tapCopyCheckedItemsEntry()

    let destination = app.buttons["copyDestination.\(Self.morningRoutineChecklistId)"]
    XCTAssertTrue(destination.waitForExistence(timeout: 5), "The destination picker didn't list Morning Routine.")
    destination.tap()

    XCTAssertTrue(destination.waitForNonExistence(timeout: 5), "The picker didn't dismiss.")
    detailBackButton.tap()
    checklistsList.staticTexts["Morning Routine"].tap()

    let morningTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(morningTable.waitForExistence(timeout: 5))
    let names = itemNames(in: morningTable)
    XCTAssertEqual(names.count, 7, "Morning Routine's own six items, plus the one copied in.")
    // Appended, not inserted: the copy sits after everything the destination already had.
    XCTAssertEqual(names.last, "Set up auto-reply on email accounts", "The copy should sit at the end.")
  }

  /// The entry stays, and stays live, so someone who has never ticked an item can still find the
  /// feature. Tapping it is what explains the rule.
  func testCopyCheckedItemsEntryExplainsItselfWithNothingChecked() {
    // Pre-Trip Checklist is seeded with none of its eleven items checked.
    checklistsList.staticTexts["Pre-Trip Checklist"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    let moreButton = app.navigationBars.buttons["checklist.more"]
    XCTAssertTrue(moreButton.waitForExistence(timeout: 5))
    moreButton.tap()

    let copyEntry = app.buttons["Copy Checked Items to…"]
    XCTAssertTrue(copyEntry.waitForExistence(timeout: 5), "The entry should be offered even with nothing to copy.")
    XCTAssertTrue(copyEntry.isEnabled, "The entry is live, not dimmed — tapping it is how the rule gets explained.")

    copyEntry.tap()

    // The toast is what the tap produces, and no picker. By label, and of any element type: the
    // card's `toast` identifier is what a subscript would match first.
    let toast = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "No checked items.")).firstMatch
    XCTAssertTrue(toast.waitForExistence(timeout: 5), "The toast didn't appear.")
    XCTAssertFalse(
      app.buttons["copyDestination.newChecklist"].exists,
      "With nothing to copy there is nothing to pick a destination for.",
    )
  }
}
