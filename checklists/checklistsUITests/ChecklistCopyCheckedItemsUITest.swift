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
    app.navigationBars.buttons["Back"]
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

    let nameField = app.textFields["copyDestination.newChecklistName"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 5), "The destination picker didn't appear.")
    nameField.tapForKeyboardFocus()
    nameField.typeText("Ferry Day")
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

    // The notice is what the tap produces, and the menu holds still to show it: no picker, and the
    // neighbouring entries are all still there. Checked at once, not waited for: the notice leaves on
    // a timer, and `waitForExistence` first looks about a second in, by which point under load the
    // timer has nearly run. The tap already waits for the app to go idle, so the notice is up by now.
    XCTAssertTrue(app.buttons["No checked items."].exists, "The notice didn't appear.")
    XCTAssertTrue(app.buttons["Duplicate Checklist"].exists, "The menu should still be up around the notice.")
    XCTAssertFalse(
      app.buttons["copyDestination.createNewChecklist"].exists,
      "With nothing to copy there is nothing to pick a destination for.",
    )
  }

  // MARK: - Typing a name

  private var editingDoneButton: XCUIElement {
    app.navigationBars.buttons["copyDestination.editingDone"]
  }

  /// The ✓ ends typing and nothing else: the keyboard goes, the sheet stays, nothing is copied.
  func testDoneEndsTypingWithoutCopying() {
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))
    tapCopyCheckedItemsEntry()

    let nameField = app.textFields["copyDestination.newChecklistName"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 5), "The destination picker didn't appear.")
    XCTAssertFalse(editingDoneButton.exists, "Done should only show while the name is being typed.")
    nameField.tapForKeyboardFocus()
    XCTAssertTrue(editingDoneButton.waitForExistence(timeout: 5), "Focusing the name didn't bring Done into the bar.")

    editingDoneButton.tap()

    XCTAssertTrue(editingDoneButton.waitForNonExistence(timeout: 5), "Done stayed after ending typing.")
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "The keyboard stayed up.")
    XCTAssertTrue(nameField.exists, "Done should leave the picker up, with nothing copied.")
  }

  /// While the name is being typed, a destination row just above the keyboard still takes a tap:
  /// nothing rides above the keyboard to swallow it.
  @MainActor func testDestinationJustAboveKeyboardTakesTapWhileTyping() throws {
    // Enough destinations that one reaches down to the keyboard; the seed alone has two.
    for name in ["Packing A", "Packing B", "Packing C", "Packing D", "Packing E"] {
      app.openCreateSheet()
      app.typeText(name)
      app.finishCreateSheet()
      XCTAssertTrue(checklistsList.staticTexts[name].waitForExistence(timeout: 5))
    }

    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))
    tapCopyCheckedItemsEntry()

    let nameField = app.textFields["copyDestination.newChecklistName"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 5), "The destination picker didn't appear.")
    nameField.tapForKeyboardFocus()
    let keyboard = app.waitForSoftwareKeyboard("Keyboard didn't appear for the name.")
    XCTAssertTrue(editingDoneButton.waitForExistence(timeout: 5), "Focusing the name didn't bring Done into the bar.")

    // A point in the band a keyboard toolbar occupies: centred 68pt above the keyboard, as the bar
    // this replaced measured. Tapped there rather than at the row's centre, which can fall below it.
    let bandY = keyboard.frame.minY - 68
    let rows = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'copyDestination.' AND NOT identifier IN %@", [
        "copyDestination.createNewChecklist", "copyDestination.editingDone",
      ]),
    )
    let rowInBand = (0 ..< rows.count)
      .map { rows.element(boundBy: $0) }
      .first { $0.frame.minY <= bandY && $0.frame.maxY >= bandY }
    let row = try XCTUnwrap(rowInBand, "No destination reaches the band above the keyboard.")

    row.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: 40, dy: bandY - row.frame.minY))
      .tap()

    XCTAssertTrue(nameField.waitForNonExistence(timeout: 5), "The tap above the keyboard didn't reach the destination.")
  }
}
