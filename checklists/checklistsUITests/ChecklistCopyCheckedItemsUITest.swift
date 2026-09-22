//
//  ChecklistCopyCheckedItemsUITest.swift
//  checklistsUITests
//

import XCTest

/// The detail screen's "Copy Checked Items to…" entry and the destination picker behind it.
///
/// Its own file rather than a section of `checklistUITest`: that one is already at the lint's
/// file-length ceiling, and `checklistCreateUITest` set the precedent of splitting a flow out.
///
/// Navigation-bar buttons are matched without naming the bar — see `checklistUITest.detailBackButton`
/// for why naming it makes a query depend on scroll position.
class ChecklistCopyCheckedItemsUITest: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["-UITests1"]
    app.launch()
    XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5), "Main checklists list did not appear after launch.")
  }

  override func tearDownWithError() throws {}

  /// See `checklistUITest.checklistsList`.
  private var checklistsList: XCUIElementQuery {
    app.collectionViews
  }

  private var detailBackButton: XCUIElement {
    app.navigationBars.buttons["Back"]
  }

  // MARK: - Helpers

  /// The seeded Morning Routine checklist's id, which the destination picker's row for it carries.
  /// Addressed by id rather than by name because the list screen's row of the same name is still in
  /// the tree behind the sheet.
  private static let morningRoutineChecklistId = "C4EC1157-0000-4000-A000-000000000001"

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

  /// Morning Routine is seeded with five of its six items checked, so the entry is offered without
  /// having to tick anything first.
  func testCopyCheckedItemsToANewUntitledChecklist() {
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    tapCopyCheckedItemsEntry()

    // Committing the name field blank is legal, which is why the button beside it is always
    // enabled: the new checklist takes the name an unnamed one carries everywhere else.
    let createButton = app.buttons["copyDestination.createNewChecklist"]
    XCTAssertTrue(createButton.waitForExistence(timeout: 5), "The destination picker didn't appear.")
    createButton.tap()

    // Staying put is the point: the picker dismisses onto the checklist it was started from.
    XCTAssertTrue(createButton.waitForNonExistence(timeout: 5), "The picker didn't dismiss.")
    XCTAssertTrue(app.tables["ChecklistTableView"].exists, "The copy shouldn't navigate away from the source.")

    detailBackButton.tap()
    XCTAssertTrue(checklistsList.staticTexts["untitled checklist"].waitForExistence(timeout: 5))
    XCTAssertTrue(
      checklistsList.cells.element(boundBy: 0).staticTexts["untitled checklist"].exists,
      "A checklist made out of a subset goes to the top, where a new checklist goes."
    )

    // The five checked items came over; the sixth, unchecked, did not.
    checklistsList.staticTexts["untitled checklist"].tap()
    let copyTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(copyTable.waitForExistence(timeout: 5))
    XCTAssertTrue(copyTable.staticTexts["START COFFEE MAKER"].exists)
    XCTAssertTrue(copyTable.staticTexts["Argue politics on Facebook"].exists)
    XCTAssertFalse(copyTable.staticTexts["Journaling"].exists, "An unchecked item shouldn't have been copied.")
    XCTAssertFalse(
      copyTable.children(matching: .cell).element(boundBy: 0).buttons["Checkbox"].isSelected,
      "Copied items should arrive unchecked."
    )
  }

  func testCopyCheckedItemsToANamedNewChecklist() {
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    tapCopyCheckedItemsEntry()

    let nameField = app.textFields["copyDestination.newChecklistName"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 5), "The destination picker didn't appear.")
    nameField.tap()
    app.typeText("Ferry Day")
    app.buttons["copyDestination.createNewChecklist"].tap()

    XCTAssertTrue(nameField.waitForNonExistence(timeout: 5), "The picker didn't dismiss.")
    detailBackButton.tap()
    XCTAssertTrue(checklistsList.staticTexts["Ferry Day"].waitForExistence(timeout: 5))
  }

  /// The items land at the end of the destination, which is where items normally arrive.
  func testCopyCheckedItemsToAnExistingChecklist() {
    checklistsList.staticTexts["Pre-Trip Checklist"].tap()
    let preTripTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(preTripTable.waitForExistence(timeout: 5))
    preTripTable.children(matching: .cell).element(boundBy: 0).buttons["Checkbox"].tap()

    tapCopyCheckedItemsEntry()

    let destination = app.buttons["copyDestination.\(Self.morningRoutineChecklistId)"]
    XCTAssertTrue(destination.waitForExistence(timeout: 5), "The destination picker didn't list Morning Routine.")
    destination.tap()

    XCTAssertTrue(destination.waitForNonExistence(timeout: 5), "The picker didn't dismiss.")
    detailBackButton.tap()
    checklistsList.staticTexts["Morning Routine"].tap()

    let morningTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(morningTable.waitForExistence(timeout: 5))
    let copied = morningTable.staticTexts["Set up auto-reply on email accounts"]
    XCTAssertTrue(copied.waitForExistence(timeout: 5), "The copied item didn't arrive.")
    // Appended, not inserted: the last row before the add-item footer is the one that arrived.
    let lastCell = morningTable.children(matching: .cell).element(boundBy: 6)
    XCTAssertTrue(lastCell.staticTexts["Set up auto-reply on email accounts"].exists, "The copy should sit at the end.")
  }

  /// Omitted rather than disabled, matching how the create sheet drops the whole non-destructive
  /// section.
  func testCopyCheckedItemsEntryIsAbsentWithNothingChecked() {
    // Pre-Trip Checklist is seeded with none of its eleven items checked.
    checklistsList.staticTexts["Pre-Trip Checklist"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    let moreButton = app.navigationBars.buttons["checklist.more"]
    XCTAssertTrue(moreButton.waitForExistence(timeout: 5))
    moreButton.tap()

    // Waiting on a neighbouring entry rather than on the absent one, so this asserts the menu is
    // up before asserting what is missing from it.
    XCTAssertTrue(app.buttons["Duplicate Checklist"].waitForExistence(timeout: 5), "The overflow menu didn't open.")
    XCTAssertFalse(app.buttons["Copy Checked Items to…"].exists, "Nothing is checked, so there is nothing to copy.")
  }
}
