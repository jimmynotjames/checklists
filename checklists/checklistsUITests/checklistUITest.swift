//
//  checklistUITest.swift
//  checklistsUITests
//
//  Created by Jimmy Ho on 12/31/20.
//

import XCTest

private let loremIspum = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
  + "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. "
  + "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. "
  + "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

class checklistUITest: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["-UITests1"]
    app.launch()
    XCTAssertTrue(app.tables.firstMatch.waitForExistence(timeout: 5), "Main checklists list did not appear after launch.")
  }

  override func tearDownWithError() throws {}

  /**
   1. Go to the "Morning Routine" Checklist.
   2. Edit Checklist Name to "Morning Ritual"
   3. Add Checklist Notes to empty notes.
   4. Go back to main page and check that text was updated.
   5. Tap back into that same Checklist and check that stuff is still updated.
   */
  func testEditHeaderInfo() {
    let newChecklistName = "Morning Ritual"
    let newChecklistNotes = "Do this mindfully!!!"

    let tablesQuery = app.tables
    tablesQuery/*@START_MENU_TOKEN@*/ .staticTexts["Morning Routine"]/*[[".cells.staticTexts[\"Morning Routine\"]",".staticTexts[\"Morning Routine\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()

    let checklistNameField = tablesQuery.textFields["Checklist Name: "]
    checklistNameField.tap()
    checklistNameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
    checklistNameField.typeText("Ritual")

    let checklistNotesTextView = tablesQuery.textViews["Checklist Notes: "]
    checklistNotesTextView.tap()
    checklistNotesTextView.typeText(newChecklistNotes)

    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
    // The main list's notes preview label has an explicit accessibilityIdentifier
    // ("checklistNotesLabel", set on every row), so it no longer matches by its rendered text via the
    // bare `staticTexts[...]` subscript the way an unlabeled element would — look it up by identifier
    // and assert on its `.label` instead.
    let morningRoutineNotesLabel = app.tables.children(matching: .cell).element(boundBy: 0).staticTexts["checklistNotesLabel"]
    XCTAssert(app.staticTexts[newChecklistName].exists)
    XCTAssertTrue(morningRoutineNotesLabel.waitForExistence(timeout: 5), "Notes label didn't appear on the main list after the pop-back animation.")
    XCTAssertEqual(morningRoutineNotesLabel.label, newChecklistNotes)

    app.staticTexts[newChecklistName].tap()
    // Back on the detail screen, the name is rendered in a text field, not a static text (the
    // static-text check above only made sense on the main list) — check the field's value instead.
    let checklistNameFieldAfterReentry = app.tables["ChecklistTableView"].textFields["checklistNameField"]
    let checklistNotesTextViewAfterReentry = app.tables["ChecklistTableView"].textViews["checklistNotesTextView"]
    XCTAssertTrue(checklistNameFieldAfterReentry.waitForExistence(timeout: 5))
    XCTAssertEqual(checklistNameFieldAfterReentry.value as? String, newChecklistName)
    XCTAssertEqual(checklistNotesTextViewAfterReentry.value as? String, newChecklistNotes)
  }

  func testCheckboxesAndReset() {
    let tablesQuery = app.tables

    // Go into Pre-Trip Checklist. 11 elements, none checked.
    tablesQuery/*@START_MENU_TOKEN@*/
      .staticTexts["Pre-Trip Checklist"]/*[[".cells.staticTexts[\"Pre-Trip Checklist\"]",".staticTexts[\"Pre-Trip Checklist\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()
    tablesQuery.children(matching: .cell).element(boundBy: 0).buttons["Checkbox"].tap()
    tablesQuery.children(matching: .cell).element(boundBy: 5).buttons["Checkbox"].tap()

    // Check 2 of the items. Verify that they were checked. Verify status icon updated
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 0).buttons["Checkbox"].isSelected == true)
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 5).buttons["Checkbox"].isSelected == true)
    assertPercentComplete(tablesQuery["ChecklistTableView"], numCheckedItems: 2, numItems: 11) // Check that circular status icon updated. 2/11 -> 18%

    // Reset checklist. Verify again.
    app.navigationBars["checklists.ChecklistView"].buttons["Reset"].tap()

    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 0).buttons["Checkbox"].isSelected == false)
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 5).buttons["Checkbox"].isSelected == false)
    assertPercentComplete(tablesQuery["ChecklistTableView"], numCheckedItems: 0, numItems: 11) // Check that circular status icon updated. 0/11 -> 0%

    // Check 2 different items, Verify again
    tablesQuery.children(matching: .cell).element(boundBy: 2).buttons["Checkbox"].tap()
    tablesQuery.children(matching: .cell).element(boundBy: 10).buttons["Checkbox"].tap()
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 2).buttons["Checkbox"].isSelected == true)
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 10).buttons["Checkbox"].isSelected == true)

    // Go Back. Verify circular status is updated on main Checklists page.
    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
    // Check that circular status icon updated on Checklists main page. 2/11 -> 18%
    assertPercentComplete(tablesQuery.children(matching: .cell).element(boundBy: 2), numCheckedItems: 2, numItems: 11)
  }

  func testItemDeletion() {
    let tablesQuery = app.tables
    tablesQuery.staticTexts["Morning Routine"].tap()

    // Get name of current item about to be deleted
    guard let itemName = tablesQuery.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String else {
      XCTFail("Item name text view value was not a String"); return
    }

    assertPercentComplete(tablesQuery["ChecklistTableView"], numCheckedItems: 5, numItems: 6) // Check circular status icon initial status. 5/6

    let cell = tablesQuery.children(matching: .cell).element(boundBy: 1)
    cell.swipeLeft() // "Yoga/meditation"
    tablesQuery/*@START_MENU_TOKEN@*/ .buttons["Delete"]/*[[".cells.buttons[\"Delete\"]",".buttons[\"Delete\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()

    // Check that item name is no longer there.
    guard let newItemName = tablesQuery.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String else {
      XCTFail("Item name text view value was not a String"); return
    }
    XCTAssert(newItemName != itemName)
    assertPercentComplete(tablesQuery["ChecklistTableView"], numCheckedItems: 4, numItems: 5) // Check that circular status icon updated. 4/5
  }

  /**
   You can create an Item by tapping Next on keyboard and remove one by tapping Delete
   on an empty Item.
   */
  func testAddDeleteItemsWithCursor() throws {
    app.tables/*@START_MENU_TOKEN@*/
      .staticTexts["Pre-Trip Checklist"]/*[[".cells.staticTexts[\"Pre-Trip Checklist\"]",".staticTexts[\"Pre-Trip Checklist\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()

    let checklisttableviewTable = app.tables["ChecklistTableView"]
    let itemNameTextView1a = checklisttableviewTable.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"]
    itemNameTextView1a.tap()
    let itemNameTextView1aValue = try XCTUnwrap(itemNameTextView1a.value as? String)

    let itemNameTextView2aValue = try XCTUnwrap(checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as? String)

    // Add some items with Next key
    let nextButton = app/*@START_MENU_TOKEN@*/ .buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
    nextButton.tap()
    app.typeText("X")

    nextButton.tap()
    app.typeText("Y")

    nextButton.tap()
    app.typeText("Z")

    nextButton.tap()

    // Remove those items with Delete key and nothing else.
    let deleteKey = app/*@START_MENU_TOKEN@*/ .keys["delete"]/*[[".keyboards.keys[\"delete\"]",".keys[\"delete\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
    for _ in 1 ... 7 {
      deleteKey.tap()
    }
    app.toolbars["Toolbar"].buttons["Done"].tap()

    // Test that original state was restored.
    let itemNameTextView1bValue = try XCTUnwrap(checklisttableviewTable.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String)
    XCTAssert(itemNameTextView1aValue == itemNameTextView1bValue)

    var itemNameTextView2bValue = try XCTUnwrap(checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as? String)
    XCTAssert(itemNameTextView2aValue == itemNameTextView2bValue)

    // Add notes to an Item, then delete the notes and keep tapping Delete. Should not spill into Name field.
    checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].tap()
    checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNotesTextView"].tap()
    app.typeText("Make sure key in planter.")
    for _ in 1 ... 30 {
      deleteKey.tap()
    }
    app.toolbars["Toolbar"].buttons["Done"].tap()

    // Check that Name field still preserved.
    itemNameTextView2bValue = try XCTUnwrap(checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as? String)
    XCTAssert(itemNameTextView2aValue == itemNameTextView2bValue)
  }

  func testLongChecklistNotesWithScrolling() {
    app.tables/*@START_MENU_TOKEN@*/
      .staticTexts["Weekend Getaway Essentials"]/*[[".cells.staticTexts[\"Weekend Getaway Essentials\"]",".staticTexts[\"Weekend Getaway Essentials\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()

    let checklistTableView = app.tables["ChecklistTableView"]
    let checklistnotestextviewTextView = checklistTableView.textViews["checklistNotesTextView"]
    checklistnotestextviewTextView.tap()

    let notes = loremIspum + "\n" + loremIspum
    app.typeText(notes)

    app.toolbars["Toolbar"].buttons["Done"].tap()

    checklistTableView.swipeUp()

    app.navigationBars["Weekend Getaway Essentials"].buttons["Back"].tap()

    let weekendGetawayNotes = app.tables.children(matching: .cell).element(boundBy: 1).staticTexts["checklistNotesLabel"].label
    XCTAssert(weekendGetawayNotes.starts(with: notes.prefix(15)))
  }

  func testChecklistReordering1() throws {
    app.tables/*@START_MENU_TOKEN@*/
      .staticTexts["Weekend Getaway Essentials"]/*[[".cells.staticTexts[\"Weekend Getaway Essentials\"]",".staticTexts[\"Weekend Getaway Essentials\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()
    let checklistTableView = app.tables["ChecklistTableView"]

    // Go to last Item and move to index 8.
    checklistTableView.swipeUp()
    let item8NameTextView = checklistTableView.children(matching: .cell).element(boundBy: 7).textViews["itemNameTextView"]
    let item12NameTextView = checklistTableView.children(matching: .cell).element(boundBy: 11).textViews["itemNameTextView"]

    let item12Name = try XCTUnwrap(item12NameTextView.value as? String)

    item12NameTextView.press(forDuration: 0.75, thenDragTo: item8NameTextView)

    // Now the original last item should now be at index 7.
    var item7Value = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 7).textViews["itemNameTextView"].value as? String)
    XCTAssert(item12Name == item7Value)

    // For good measure, go Back to main page, then back into Checklist, and see if all elements are still ordered correctly.
    // NOTE: the nav bar title only shows the checklist name once the table view is scrolled past a
    // threshold (ChecklistViewController.scrollViewDidScroll); the drag-and-drop reorder above leaves
    // the table scrolled back near the top, so the title (and thus the nav bar's matched identifier)
    // is nil here — look the bar up by the view controller's default identifier instead.
    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
    app.tables/*@START_MENU_TOKEN@*/
      .staticTexts["Weekend Getaway Essentials"]/*[[".cells.staticTexts[\"Weekend Getaway Essentials\"]",".staticTexts[\"Weekend Getaway Essentials\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()
    checklistTableView.swipeUp()
    item7Value = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 7).textViews["itemNameTextView"].value as? String)
    XCTAssert(item12Name == item7Value)
  }

  func testChecklistReordering2() throws {
    app.tables.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]

    // Go to last Item and move to index 0.
    let fromNameTextView = checklistTableView.children(matching: .cell).element(boundBy: 5).textViews["itemNameTextView"]
    let toNameTextView = checklistTableView.children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"]

    let fromName = try XCTUnwrap(fromNameTextView.value as? String)
    let item1Name = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"].value as? String)
    let item2Name = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String)

    fromNameTextView.press(forDuration: 0.75, thenDragTo: toNameTextView)

    var atIndex0 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"].value as? String)
    var atIndex1 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String)
    var atIndex2 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as? String)
    XCTAssert(fromName == atIndex0) // Now the original last item should now be at index 7.
    XCTAssert(item1Name == atIndex1) // The original item 1 should now be shifted down to item 2.
    XCTAssert(item2Name == atIndex2) // The original item 2 should now be shifted down to item 3.

    // For good measure, go Back to main page, then back into Checklist, and see if all elements are still ordered correctly.
    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
    app.tables.staticTexts["Morning Routine"].tap()
    atIndex0 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"].value as? String)
    atIndex1 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String)
    atIndex2 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as? String)
    XCTAssert(fromName == atIndex0) // Now the original last item should now be at index 7.
    XCTAssert(item1Name == atIndex1) // The original item 1 should now be shifted down to item 2.
    XCTAssert(item2Name == atIndex2) // The original item 2 should now be shifted down to item 3.
  }

  func testChecklistEditItemName() throws {
    app.tables.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]

    let item2NameTextView = checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"]
    let item2Name = try XCTUnwrap(item2NameTextView.value as? String)
    item2NameTextView.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()

    let n = 11
    let deleteKey = app/*@START_MENU_TOKEN@*/ .keys["delete"]/*[[".keyboards.keys[\"delete\"]",".keys[\"delete\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
    for _ in 1 ... n {
      deleteKey.tap()
    }

    var trimmedName = try XCTUnwrap(item2NameTextView.value as? String)
    XCTAssert(item2Name.prefix(item2Name.count - n) == trimmedName)

    // For good measure, back out, and go back in again, and check again.
    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
    app.tables.staticTexts["Morning Routine"].tap()
    trimmedName = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String)
    XCTAssert(item2Name.prefix(item2Name.count - n) == trimmedName)
  }

  private func percentCompleteString(numCheckedItems: Int, numItems: Int) -> String {
    String(format: "Checklist %.0f percent complete", 100.0 * Double(numCheckedItems) / Double(numItems))
  }

  /// Asserts that `parentElement` contains the circular status icon's accessibility element with the
  /// expected percent-complete value. Tightened from a bare `.value != nil` check (which silently
  /// passes even when no matching element exists) to a real existence check plus an equality
  /// assertion, so a wrong or missing value actually fails the test with a useful message.
  ///
  /// Waits rather than checking `.exists` outright: several call sites assert immediately after a
  /// Back tap, and the destination cell's status icon isn't necessarily laid out the instant the pop
  /// transition starts. The old `.value != nil` form could never fail, so the timing didn't matter;
  /// now that the assertion is real, an unwaited check would flake under load.
  private func assertPercentComplete(
    _ parentElement: XCUIElement,
    numCheckedItems: Int,
    numItems: Int,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let expected = percentCompleteString(numCheckedItems: numCheckedItems, numItems: numItems)
    let element = parentElement.otherElements[expected]
    XCTAssertTrue(
      element.waitForExistence(timeout: 5),
      "No percent-complete element found with accessibility value \"\(expected)\"",
      file: file,
      line: line
    )
    XCTAssertEqual(element.value as? String, expected, file: file, line: line)
  }

  func testAddItemsAtEnd() throws {
    let newItemName1 = "Walk the dog"
    let newItemName2 = "Turn off coffee maker"

    app.tables.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]

    checklistTableView.swipeUp()

    let numItems = checklistTableView.children(matching: .cell).count
    var numCheckedItems = 0
    for i in 0 ..< numItems {
      numCheckedItems += (checklistTableView.children(matching: .cell).element(boundBy: i).buttons["Checkbox"].isSelected) ? 1 : 0
    }
    assertPercentComplete(checklistTableView, numCheckedItems: numCheckedItems, numItems: numItems)

    // Add an Item using Add button.
    checklistTableView.buttons["Add"].tap()
    app.typeText(newItemName1)

    // Count should have increased by one.
    XCTAssert(checklistTableView.children(matching: .cell).count == numItems + 1)
    assertPercentComplete(checklistTableView, numCheckedItems: numCheckedItems, numItems: numItems + 1) // Check that circular status icon updated.

    // Inserting the new item scrolls the table back near the top (see `insertNewItem`), which clears
    // the nav bar title (and thus the identifier this bar matches by) — see the note in
    // testChecklistReordering1 for the same reason the identifier below is "checklists.ChecklistView"
    // rather than the checklist's name.
    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
    // Check that circular status icon updated on Checklists page.
    assertPercentComplete(app.tables.children(matching: .cell).element(boundBy: 0), numCheckedItems: numCheckedItems, numItems: numItems + 1)
    app.tables.staticTexts["Morning Routine"].tap()

    // Check that changes persisted.
    XCTAssert(checklistTableView.children(matching: .cell).count == numItems + 1)
    XCTAssert(checklistTableView.children(matching: .cell).element(boundBy: numItems).textViews["itemNameTextView"].value as? String == newItemName1)
    assertPercentComplete(checklistTableView, numCheckedItems: numCheckedItems, numItems: numItems + 1) // Check that circular status icon updated.

    // Now add something at end using keyboard Return key ("Next") key.
    let lastItemNameTextView = checklistTableView.children(matching: .cell).element(boundBy: numItems).textViews["itemNameTextView"]
    lastItemNameTextView.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()

    app/*@START_MENU_TOKEN@*/ .buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()
    app.typeText(newItemName2)
    app.toolbars["Toolbar"].buttons["Done"].tap()

    XCTAssert(checklistTableView.children(matching: .cell).count == numItems + 2)
    assertPercentComplete(checklistTableView, numCheckedItems: numCheckedItems, numItems: numItems + 2) // Check that circular status icon updated.
    var lastItemName = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: numItems + 1).textViews["itemNameTextView"].value as? String)
    XCTAssert(lastItemName == newItemName2)

    // Go back to main page, back into Checklist, and check again.
    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
    // Check that circular status icon updated on Checklists page.
    assertPercentComplete(app.tables.children(matching: .cell).element(boundBy: 0), numCheckedItems: numCheckedItems, numItems: numItems + 2)
    app.tables.staticTexts["Morning Routine"].tap()

    XCTAssert(checklistTableView.children(matching: .cell).count == numItems + 2)
    assertPercentComplete(checklistTableView, numCheckedItems: numCheckedItems, numItems: numItems + 2) // Check that circular status icon updated.
    lastItemName = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: numItems + 1).textViews["itemNameTextView"].value as? String)
    XCTAssert(lastItemName == newItemName2)
  }
}
