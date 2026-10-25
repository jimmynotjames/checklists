//
//  checklistCreateUITest.swift
//  checklistsUITests
//
//  Created by Jimmy Ho on 1/2/21.
//

import XCTest

class checklistCreateUITest: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["-UITests1"]
    app.launch()
    XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5), "Main checklists list did not appear after launch.")
  }

  override func tearDownWithError() throws {}

  /// Navigation-bar buttons here are matched without naming the bar — see
  /// ChecklistDetailUITestCase.detailBackButton for why naming it makes a query depend on scroll position.
  ///
  /// See ChecklistDetailUITestCase.checklistsList.
  private var checklistsList: XCUIElementQuery {
    app.collectionViews
  }

  /**
   1a. Create a checklist with 3 Checklist Name, Notes, and 3 items, one item with Item Notes.
   1b. Do it in a way that exercises different ways of adding a new Item.
   2. Then go Back to main page, then tap back in and verify that it's all there, in the right order.
   */
  func testCreateChecklistAndAddItems() {
    let checklistName = "Mindfulness Checklist"
    let checklistNotes = "New year! New checklist!"
    let item1Name = "Gratitude - 1 min"
    let item2Name = "Optional Journaling - 5-10 min"
    let item2NotesLine1 = "The day's events, reactions, feelings, random thoughts, forward-looking intentions?"
    let item2NotesLine2 = "Just write something; don't worry about quality!"
    let item3Name = "Expand love and presence as far as possible."
    let item4Name = "3 deep breaths. Complete!"

    var checklistTable = app.tables["ChecklistTableView"]
    app.openCreateSheet()
    XCTAssertTrue(checklistTable.waitForExistence(timeout: 5))

    // Should auto-focus on Checklist Name field
    app.typeText(checklistName)
    app.pressReturnKey()

    // After tapping done on Checklist Name, should auto-focus on first Item without taps.
    app.typeText(item1Name) // Item 1

    // Create item 2 via the keyboard's Next key.
    app.pressReturnKey() // Should auto-create Item 2 and auto-focus to write in.
    app.typeText(item2Name) // Item 2

    // Add Item Notes to Item 2
    var cell = checklistTable.children(matching: .cell).element(boundBy: 1)
    let item2NotesTextView = cell.textViews["itemNotesTextView"]
    item2NotesTextView.tap()
    app.typeText(item2NotesLine1)
    item2NotesTextView.pressReturnKey()
    app.typeText(item2NotesLine2)

    // Create Item 3 via Add Button without dismissing keyboard from prior.
    checklistTable.buttons["Add"].tap()
    app.typeText(item3Name)
    app.tapChecklistEditingDone()

    // Create Item 4 via Add button after dismissing keyboard from prior.
    checklistTable.buttons["Add"].tap()
    app.typeText(item4Name)
    app.tapChecklistEditingDone()

    // Add Checklist Notes back at the top
    checklistTable.textViews["checklistNotesTextView"].tap()
    app.typeText(checklistNotes)

    // Finish and dismiss modal
    app.finishCreateSheet()

    // Go back in to Checklist to check stuff.
    let mindfulnessRow = checklistsList.staticTexts["Mindfulness Checklist"]
    XCTAssertTrue(mindfulnessRow.waitForExistence(timeout: 5))
    mindfulnessRow.tap()

    checklistTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTable.waitForExistence(timeout: 5))
    XCTAssert((checklistTable.textFields["checklistNameField"].value as? String ?? "") == checklistName)
    XCTAssert((checklistTable.textViews["checklistNotesTextView"].value as? String ?? "") == checklistNotes)

    cell = checklistTable.children(matching: .cell).element(boundBy: 0)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item1Name)

    cell = checklistTable.children(matching: .cell).element(boundBy: 1)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item2Name)
    XCTAssert((cell.textViews["itemNotesTextView"].value as? String ?? "") == (item2NotesLine1 + "\n" + item2NotesLine2))

    // Now remove the notes via Delete key, but keep deleting until some of Item Name is deleted
    let itemNotesTextView = cell.textViews["itemNotesTextView"]
    itemNotesTextView.tap()
    itemNotesTextView.press(forDuration: 0.5)
    // The edit menu animates in, and comes back with Cut only after Select All has selected.
    let selectAll = app.menuItems["Select All"]
    XCTAssertTrue(selectAll.waitForExistence(timeout: 5), "The edit menu didn't offer Select All.")
    selectAll.tap()
    let cut = app.menuItems["Cut"]
    XCTAssertTrue(cut.waitForExistence(timeout: 5), "The edit menu didn't offer Cut after Select All.")
    cut.tap()
    app.tapChecklistEditingDone()

    // Emptied, the notes field collapses and leaves the accessibility tree.
    XCTAssertFalse(cell.textViews["itemNotesTextView"].waitForExistence(timeout: 2), "Emptied notes should collapse the notes field.")

    cell = checklistTable.children(matching: .cell).element(boundBy: 2)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item3Name)

    cell = checklistTable.children(matching: .cell).element(boundBy: 3)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item4Name)

    // Go back to main page.
    app.navigationBars.buttons["Back"].tap()
  }

  func testCreateChecklist2() {
    app.openCreateSheet()
    let checklistTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTable.waitForExistence(timeout: 5))

    let checklistName = "Mindfulness Checklist"
    let item1Name = "Gratitude - 1 min"
    let item2Name = "Optional Journaling - 5-10 min"
    let item3Name = "Expand love and presence as far as possible."
    let item4Name = "3 deep breaths. Complete!"

    // Should auto-focus on Checklist Name field
    app.typeText(checklistName)
    app.pressReturnKey()

    // After tapping done on Checklist Name, should auto-focus on first Item without taps.
    app.typeText(item1Name) // Item 1

    // Create Item 3 via Add Button without dismissing keyboard from prior.
    app.pressReturnKey()
    app.typeText(item3Name)

    // Create Item 4 via Add button after dismissing keyboard from prior.
    app.pressReturnKey()
    app.typeText(item4Name)
    app.tapChecklistEditingDone()

    // Pop back in at Item 1 and insert something.
    checklistTable.children(matching: .cell).element(boundBy: 0).tap()
    app.pressReturnKey()
    app.typeText(item2Name) // Item 2

    // Check Checklist Name and all the items
    XCTAssert((checklistTable.textFields["checklistNameField"].value as? String ?? "") == checklistName)

    var cell = checklistTable.children(matching: .cell).element(boundBy: 0)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item1Name)

    cell = checklistTable.children(matching: .cell).element(boundBy: 1)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item2Name)

    cell = checklistTable.children(matching: .cell).element(boundBy: 2)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item3Name)

    cell = checklistTable.children(matching: .cell).element(boundBy: 3)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item4Name)

    // Finish and dismiss modal
    app.finishCreateSheet()
  }

  /// Trailing empty Items should be auto-deleted.
  func testItemCleanup() {
    let checklistName = "Mindfulness Checklist"
    let item1Name = "Gratitude - 1 min"

    app.openCreateSheet()
    let checklistTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTable.waitForExistence(timeout: 5))

    // Should auto-focus on Checklist Name field
    app.typeText(checklistName)
    app.pressReturnKey() // Should auto-focus on first Item

    app.pressReturnKey()
    app.typeText(item1Name)
    app.pressReturnKey()
    app.pressReturnKey()

    // Final state: { empty, item1, empty, empty }

    app.tapChecklistEditingDone()
    XCTAssert(checklistTable.children(matching: .cell).count == 4)

    // Finish and dismiss modal, go back to check stuff
    app.finishCreateSheet()
    let mindfulnessRow = checklistsList.staticTexts["Mindfulness Checklist"]
    XCTAssertTrue(mindfulnessRow.waitForExistence(timeout: 5))
    mindfulnessRow.tap()

    // Trailing empty Items should have been removed { empty, item1 }
    XCTAssert(checklistTable.children(matching: .cell).count == 2)
    XCTAssert(checklistTable.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String == item1Name)

    let item1NameTextView = checklistTable.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"]
    item1NameTextView.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()

    // Remove the text only, leaving Item with empty field.
    item1NameTextView.pressDeleteKey(item1Name.count)
    app.tapChecklistEditingDone()

    // Finish and dismiss modal, go back to check stuff
    app.navigationBars.buttons["Back"].tap()
    let mindfulnessRowAgain = checklistsList.staticTexts["Mindfulness Checklist"]
    XCTAssertTrue(mindfulnessRowAgain.waitForExistence(timeout: 5))
    mindfulnessRowAgain.tap()

    XCTAssert(checklistTable.children(matching: .cell).count == 1) // Second item should have been stripped automatically.
  }

  func testCreateBlankChecklist() {
    // A tap while the sheet is still sliding up is dropped, so this waits for the name field's focus
    // before tapping.
    app.openCreateSheet()
    app.finishCreateSheet()

    let untitled = checklistsList.cells.element(boundBy: 0).staticTexts["untitled checklist"]
    XCTAssertTrue(untitled.waitForExistence(timeout: 5))
  }

  func testCreateChecklistAndRemoveAllItems() {
    let checklistName = "XYZ"
    app.openCreateSheet() // Should pull up modal and auto-focus on name. Leave Checklist Name blank.

    app.typeText(checklistName) // Arbitrary Checklist Name
    app.pressReturnKey() // Should auto-focus on first Item after tapping done Checklist Name
    app.typeText("X")
    app.pressReturnKey()
    app.typeText("Y")

    // Remove all items plus some more delete key tapping for good measure.
    app.pressDeleteKey(8)
    app.finishCreateSheet()

    XCTAssertTrue(app.staticTexts[checklistName].waitForExistence(timeout: 5))
    app.staticTexts[checklistName].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))
    XCTAssert(app.tables["ChecklistTableView"].children(matching: .cell).count == 1)
    XCTAssert(app.tables["ChecklistTableView"].children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"].value as? String == "")
  }

  func testEmojis() {
    let checklistName = "Meditation 🧘🏼"
    let itemName1 = "🧘🏼 10 min"
    let itemName2 = "Express gratitude to universe."
    let itemName3 = "🍳"

    app.openCreateSheet() // Should pull up modal and auto-focus on name. Leave Checklist Name blank.

    app.typeText(checklistName) // Arbitrary Checklist Name
    app.pressReturnKey() // Should auto-focus on first Item after tapping done Checklist Name
    app.typeText(itemName1)
    app.pressReturnKey()
    app.typeText(itemName2)
    app.pressReturnKey()
    app.typeText(itemName3)

    app.finishCreateSheet()
    XCTAssertTrue(app.staticTexts[checklistName].waitForExistence(timeout: 5))
    app.staticTexts[checklistName].tap()

    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))
    XCTAssert(app.tables["ChecklistTableView"].children(matching: .cell).count == 3)
    XCTAssert(app.tables["ChecklistTableView"].children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"].value as? String == itemName1)
    XCTAssert(app.tables["ChecklistTableView"].children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String == itemName2)
    XCTAssert(app.tables["ChecklistTableView"].children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as? String == itemName3)
  }

  /// The create sheet's checklist is already a real, saved row the moment this sheet appears
  /// (ChecklistsView.addChecklist), so "discard" here has to remove it from the list rather than
  /// merely closing the sheet.
  func testDiscardNewChecklist() {
    app.openCreateSheet()
    let checklistTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTable.waitForExistence(timeout: 5))
    app.typeText("Trip Prep")

    let moreButton = app.navigationBars.buttons["checklist.more"]
    XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "Overflow menu button didn't appear.")
    moreButton.tap()
    let discardEntry = app.buttons["Discard Checklist"]
    XCTAssertTrue(discardEntry.waitForExistence(timeout: 5), "Discard Checklist menu entry didn't appear.")
    discardEntry.tap()

    let confirmDiscard = app.alerts.buttons["Discard"]
    XCTAssertTrue(confirmDiscard.waitForExistence(timeout: 5), "Discard confirmation alert didn't appear.")
    confirmDiscard.tap()

    XCTAssertTrue(checklistsList.staticTexts["Morning Routine"].waitForExistence(timeout: 5))
    XCTAssertFalse(checklistsList.staticTexts["Trip Prep"].exists)
  }
}
