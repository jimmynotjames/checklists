//
//  checklistUITest.swift
//  checklistsUITests
//
//  Created by Jimmy Ho on 12/31/20.
//  Copyright © 2020 Jimmy Ho. All rights reserved.
//

import XCTest

private let loremIspum = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

class checklistUITest: XCTestCase {

  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["-UITests1"]
    app.launch()
  }

  override func tearDownWithError() throws {

  }

  /*
   1. Go to the "Morning Routine" Checklist.
   2. Edit Checklist Name to "Morning Ritual"
   3. Add Checklist Notes to empty notes.
   4. Go back to main page and check that text was updated.
   5. Tap back into that same Checklist and check that stuff is still updated.
   */
  func testEditHeaderInfo() throws {
    let newChecklistName = "Morning Ritual"
    let newChecklistNotes = "Do this mindfully!!!"

    let tablesQuery = app.tables
    tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Morning Routine"]/*[[".cells.staticTexts[\"Morning Routine\"]",".staticTexts[\"Morning Routine\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

    let checklistNameField = tablesQuery.textFields["Checklist Name: "]
    checklistNameField.tap()
    checklistNameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
    checklistNameField.typeText("Ritual")

    let checklistNotesTextView = tablesQuery.textViews["Checklist Notes: "]
    checklistNotesTextView.tap()
    checklistNotesTextView.typeText(newChecklistNotes)

    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
    XCTAssert(app.staticTexts[newChecklistName].exists)
    XCTAssert(app.staticTexts[newChecklistNotes].exists)

    app.staticTexts[newChecklistName].tap()
    XCTAssert(app.staticTexts[newChecklistName].exists)
    XCTAssert(app.staticTexts[newChecklistNotes].exists)
  }

  func testCheckboxesAndReset() {
    let tablesQuery = app.tables

    // Go into Pre-Trip Checklist. 11 elements, none checked.
    tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Pre-Trip Checklist"]/*[[".cells.staticTexts[\"Pre-Trip Checklist\"]",".staticTexts[\"Pre-Trip Checklist\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
    tablesQuery.children(matching: .cell).element(boundBy: 0).buttons["Checkbox"].tap()
    tablesQuery.children(matching: .cell).element(boundBy: 5).buttons["Checkbox"].tap()

    // Check 2 of the items. Verify that they were checked. Verify status icon updated
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 0).buttons["Checkbox"].isSelected == true)
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 5).buttons["Checkbox"].isSelected == true)
    XCTAssert(tablesQuery["ChecklistTableView"].otherElements["Checklist 18 percent complete"].value != nil) // Check that circular status icon updated. 2/11 -> 18%

    // Reset checklist. Verify again.
    app.navigationBars["checklists.ChecklistView"].buttons["Reset"].tap()

    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 0).buttons["Checkbox"].isSelected == false)
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 5).buttons["Checkbox"].isSelected == false)
    XCTAssert(tablesQuery["ChecklistTableView"].otherElements["Checklist 0 percent complete"].value != nil) // Check that circular status icon updated. 0/11 -> 0%

    // Check 2 different items, Verify again
    tablesQuery.children(matching: .cell).element(boundBy: 2).buttons["Checkbox"].tap()
    tablesQuery.children(matching: .cell).element(boundBy: 10).buttons["Checkbox"].tap()
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 2).buttons["Checkbox"].isSelected == true)
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 10).buttons["Checkbox"].isSelected == true)

    // Go Back. Verify circular status is updated on main Checklists page.
    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 2).otherElements["Checklist 18 percent complete"].value != nil) // Check that circular status icon updated on Checklists main page. 2/11 -> 18%
  }

  func testItemDeletion() {
    let tablesQuery = XCUIApplication().tables
    tablesQuery.staticTexts["Morning Routine"].tap()

    // Get name of current item about to be deleted
    guard let itemName = tablesQuery.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String else { XCTFail(); return }

    XCTAssert(tablesQuery["ChecklistTableView"].otherElements["Checklist 83 percent complete"].value != nil) // Check circular status icon initial status. 5/6

    let cell = tablesQuery.children(matching: .cell).element(boundBy: 1)
    cell.swipeLeft() // "Yoga/meditation"
    tablesQuery/*@START_MENU_TOKEN@*/.buttons["Delete"]/*[[".cells.buttons[\"Delete\"]",".buttons[\"Delete\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

    // Check that item name is no longer there.
    guard let newItemName = tablesQuery.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String else { XCTFail(); return }
    XCTAssert(newItemName != itemName)
    XCTAssert(tablesQuery["ChecklistTableView"].otherElements["Checklist 80 percent complete"].value != nil) // Check that circular status icon updated. 4/5
  }

  /*
   You can create an Item by tapping Next on keyboard and remove one by tapping Delete
   on an empty Item.
   */
  func testAddDeleteItemsWithCursor() {
    app.tables/*@START_MENU_TOKEN@*/.staticTexts["Pre-Trip Checklist"]/*[[".cells.staticTexts[\"Pre-Trip Checklist\"]",".staticTexts[\"Pre-Trip Checklist\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

    let checklisttableviewTable = app.tables["ChecklistTableView"]
    let itemNameTextView1a = checklisttableviewTable.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"]
    itemNameTextView1a.tap()
    let itemNameTextView1aValue = itemNameTextView1a.value as! String

    let itemNameTextView2aValue = checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as! String

    // Add some items with Next key
    let nextButton = app/*@START_MENU_TOKEN@*/.buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
    nextButton.tap()
    app.typeText("X")

    nextButton.tap()
    app.typeText("Y")

    nextButton.tap()
    app.typeText("Z")

    nextButton.tap()

    // Remove those items with Delete key and nothing else.
    let deleteKey = app/*@START_MENU_TOKEN@*/.keys["delete"]/*[[".keyboards.keys[\"delete\"]",".keys[\"delete\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
    for _ in 1...7 {
      deleteKey.tap()
    }
    app.toolbars["Toolbar"].buttons["Done"].tap()

    // Test that original state was restored.
    let itemNameTextView1bValue = checklisttableviewTable.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as! String
    XCTAssert(itemNameTextView1aValue == itemNameTextView1bValue)

    var itemNameTextView2bValue = checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as! String
    XCTAssert(itemNameTextView2aValue == itemNameTextView2bValue)

    // Add notes to an Item, then delete the notes and keep tapping Delete. Should not spill into Name field.
    checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].tap()
    checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNotesTextView"].tap()
    app.typeText("Make sure key in planter.")
    for _ in 1...30 {
      deleteKey.tap()
    }
    app.toolbars["Toolbar"].buttons["Done"].tap()

    // Check that Name field still preserved.
    itemNameTextView2bValue = checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as! String
    XCTAssert(itemNameTextView2aValue == itemNameTextView2bValue)
  }

  func testLongChecklistNotesWithScrolling() {
    app.tables/*@START_MENU_TOKEN@*/.staticTexts["Weekend Getaway Essentials"]/*[[".cells.staticTexts[\"Weekend Getaway Essentials\"]",".staticTexts[\"Weekend Getaway Essentials\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

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

  func testChecklistReordering1() {
    app.tables/*@START_MENU_TOKEN@*/.staticTexts["Weekend Getaway Essentials"]/*[[".cells.staticTexts[\"Weekend Getaway Essentials\"]",".staticTexts[\"Weekend Getaway Essentials\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
    let checklistTableView = app.tables["ChecklistTableView"]

    // Go to last Item and move to index 8.
    checklistTableView.swipeUp()
    let item8NameTextView = checklistTableView.children(matching: .cell).element(boundBy: 7).textViews["itemNameTextView"]
    let item12NameTextView = checklistTableView.children(matching: .cell).element(boundBy: 11).textViews["itemNameTextView"]

    let item12Name = item12NameTextView.value as! String

    item12NameTextView.press(forDuration: 0.75, thenDragTo: item8NameTextView)

    // Now the original last item should now be at index 7.
    XCTAssert(item12Name == checklistTableView.children(matching: .cell).element(boundBy: 7).textViews["itemNameTextView"].value as! String)

    // For good measure, go Back to main page, then back into Checklist, and see if all elements are still ordered correctly.
    app.navigationBars["Weekend Getaway Essentials"].buttons["Back"].tap()
    app.tables/*@START_MENU_TOKEN@*/.staticTexts["Weekend Getaway Essentials"]/*[[".cells.staticTexts[\"Weekend Getaway Essentials\"]",".staticTexts[\"Weekend Getaway Essentials\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
    checklistTableView.swipeUp()
    XCTAssert(item12Name == checklistTableView.children(matching: .cell).element(boundBy: 7).textViews["itemNameTextView"].value as! String)
  }

  func testChecklistReordering2() {
    app.tables.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]

    // Go to last Item and move to index 0.
    let fromNameTextView = checklistTableView.children(matching: .cell).element(boundBy: 5).textViews["itemNameTextView"]
    let toNameTextView = checklistTableView.children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"]

    let fromName = fromNameTextView.value as! String
    let item1Name = checklistTableView.children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"].value as! String
    let item2Name = checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as! String

    fromNameTextView.press(forDuration: 0.75, thenDragTo: toNameTextView)

    XCTAssert(fromName == checklistTableView.children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"].value as! String) // Now the original last item should now be at index 7.
    XCTAssert(item1Name == checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as! String) // The original item 1 should now be shifted down to item 2.
    XCTAssert(item2Name == checklistTableView.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as! String) // The original item 2 should now be shifted down to item 3.

    // For good measure, go Back to main page, then back into Checklist, and see if all elements are still ordered correctly.
    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
    app.tables.staticTexts["Morning Routine"].tap()
    XCTAssert(fromName == checklistTableView.children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"].value as! String) // Now the original last item should now be at index 7.
    XCTAssert(item1Name == checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as! String) // The original item 1 should now be shifted down to item 2.
    XCTAssert(item2Name == checklistTableView.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as! String) // The original item 2 should now be shifted down to item 3.
  }

  func testChecklistEditItemName() {
    app.tables.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]

    let item2NameTextView = checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"]
    let item2Name = item2NameTextView.value as! String
    item2NameTextView.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()

    let n = 11
    let deleteKey = app/*@START_MENU_TOKEN@*/.keys["delete"]/*[[".keyboards.keys[\"delete\"]",".keys[\"delete\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
    for _ in 1...n {
      deleteKey.tap()
    }

    XCTAssert(item2Name.prefix(item2Name.count - n) == item2NameTextView.value as! String)

    // For good measure, back out, and go back in again, and check again.
    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
    app.tables.staticTexts["Morning Routine"].tap()
    XCTAssert(item2Name.prefix(item2Name.count - n) == checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as! String)
  }

  private func percentCompleteString(numCheckedItems: Int, numItems: Int) -> String {
    return String(format: "Checklist %.0f percent complete", 100.0 * Double(numCheckedItems) / Double(numItems))
  }

  private func isMatchingPercentComplete(parentElement: XCUIElement, numCheckedItems: Int, numItems: Int) -> Bool {
    return parentElement.otherElements[percentCompleteString(numCheckedItems: numCheckedItems, numItems: numItems)].value != nil
  }

  func testAddItemsAtEnd() {
    let newItemName1 = "Walk the dog"
    let newItemName2 = "Turn off coffee maker"

    app.tables.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]

    checklistTableView.swipeUp()

    let numItems = checklistTableView.children(matching: .cell).count
    var numCheckedItems = 0
    for i in 0..<numItems {
      numCheckedItems = numCheckedItems + ((checklistTableView.children(matching: .cell).element(boundBy: i).buttons["Checkbox"].isSelected) ? 1 : 0)
    }
    XCTAssert(isMatchingPercentComplete(parentElement: checklistTableView, numCheckedItems: numCheckedItems, numItems: numItems))

    // Add an Item using Add button.
    checklistTableView.buttons["Add"].tap()
    app.typeText(newItemName1)

    // Count should have increased by one.
    XCTAssert(checklistTableView.children(matching: .cell).count == numItems + 1)
    XCTAssert(isMatchingPercentComplete(parentElement: checklistTableView, numCheckedItems: numCheckedItems, numItems: numItems + 1)) // Check that circular status icon updated.

    app.navigationBars["Morning Routine"].buttons["Back"].tap()
    // XCTAssert(app.tables.children(matching: .cell).element(boundBy: 0).otherElements[String(format: "%.0f percent", 100.0 * Double(numCheckedItems) / Double(numItems + 1))].exists)
    XCTAssert(isMatchingPercentComplete(parentElement: app.tables.children(matching: .cell).element(boundBy: 0), numCheckedItems: numCheckedItems, numItems: numItems + 1)) // Check that circular status icon updated on Checklists page.
    app.tables.staticTexts["Morning Routine"].tap()

    // Check that changes persisted.
    XCTAssert(checklistTableView.children(matching: .cell).count == numItems + 1)
    XCTAssert(checklistTableView.children(matching: .cell).element(boundBy: numItems).textViews["itemNameTextView"].value as! String == newItemName1)
    XCTAssert(isMatchingPercentComplete(parentElement: checklistTableView, numCheckedItems: numCheckedItems, numItems: numItems + 1)) // Check that circular status icon updated.

    // Now add something at end using keyboard Return key ("Next") key.
    let lastItemNameTextView = checklistTableView.children(matching: .cell).element(boundBy: numItems).textViews["itemNameTextView"]
    lastItemNameTextView.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()

    app/*@START_MENU_TOKEN@*/.buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
    app.typeText(newItemName2)
    app.toolbars["Toolbar"].buttons["Done"].tap()

    XCTAssert(checklistTableView.children(matching: .cell).count == numItems + 2)
    XCTAssert(isMatchingPercentComplete(parentElement: checklistTableView, numCheckedItems: numCheckedItems, numItems: numItems + 2)) // Check that circular status icon updated.
    XCTAssert(checklistTableView.children(matching: .cell).element(boundBy: numItems + 1).textViews["itemNameTextView"].value as! String == newItemName2)

    // Go back to main page, back into Checklist, and check again.
    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
    XCTAssert(isMatchingPercentComplete(parentElement: app.tables.children(matching: .cell).element(boundBy: 0), numCheckedItems: numCheckedItems, numItems: numItems + 2)) // Check that circular status icon updated on Checklists page.
    app.tables.staticTexts["Morning Routine"].tap()

    XCTAssert(checklistTableView.children(matching: .cell).count == numItems + 2)
    XCTAssert(isMatchingPercentComplete(parentElement: checklistTableView, numCheckedItems: numCheckedItems, numItems: numItems + 2)) // Check that circular status icon updated.
    XCTAssert(checklistTableView.children(matching: .cell).element(boundBy: numItems + 1).textViews["itemNameTextView"].value as! String == newItemName2)
  }
}
