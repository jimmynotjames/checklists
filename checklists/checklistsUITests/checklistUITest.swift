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
    XCTAssert(app.otherElements["18 percent"].exists) // Check that circular status icon updated. 2/11 -> 18%

    // Reset checklist. Verify again.
    app.navigationBars["checklists.ChecklistView"].buttons["Reset"].tap()

    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 0).buttons["Checkbox"].isSelected == false)
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 5).buttons["Checkbox"].isSelected == false)
    XCTAssert(app.otherElements["0 percent"].exists) // Check that circular status icon updated. 0/11 -> 0%

    // Check 2 different items, Verify again
    tablesQuery.children(matching: .cell).element(boundBy: 2).buttons["Checkbox"].tap()
    tablesQuery.children(matching: .cell).element(boundBy: 10).buttons["Checkbox"].tap()
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 2).buttons["Checkbox"].isSelected == true)
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 10).buttons["Checkbox"].isSelected == true)

    // Go Back. Verify circular status is updated on main Checklists page.
    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 2).otherElements["18 percent"].exists) // Check that circular status icon updated on Checklists main page. 2/11 -> 18%
  }

  func testItemDeletion() {
    let tablesQuery = XCUIApplication().tables
    tablesQuery.staticTexts["Morning Routine"].tap()

    // Get name of current item about to be deleted
    guard let itemName = tablesQuery.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String else { XCTFail(); return }

    XCTAssert(app.otherElements["83 percent"].exists) // Check that circular status icon updated. 5/6

    let cell = tablesQuery.children(matching: .cell).element(boundBy: 1)
    cell.swipeLeft() // "Yoga/meditation"
    tablesQuery/*@START_MENU_TOKEN@*/.buttons["Delete"]/*[[".cells.buttons[\"Delete\"]",".buttons[\"Delete\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

    // Check that item name is no longer there.
    guard let newItemName = tablesQuery.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String else { XCTFail(); return }
    XCTAssert(newItemName != itemName)
    XCTAssert(app.otherElements["80 percent"].exists) // Check that circular status icon updated. 4/5
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
    let app = XCUIApplication()
    app.tables/*@START_MENU_TOKEN@*/.staticTexts["Weekend Getaway Essentials"]/*[[".cells.staticTexts[\"Weekend Getaway Essentials\"]",".staticTexts[\"Weekend Getaway Essentials\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

    let checklisttableviewTable = app.tables["ChecklistTableView"]
    let checklistnotestextviewTextView = checklisttableviewTable.textViews["checklistNotesTextView"]
    checklistnotestextviewTextView.tap()

    let notes = loremIspum + "\n" + loremIspum
    app.typeText(notes)

    app.toolbars["Toolbar"].buttons["Done"].tap()

    checklisttableviewTable.swipeUp()

    app.navigationBars["Weekend Getaway Essentials"].buttons["Back"].tap()

    let weekendGetawayNotes = app.tables.children(matching: .cell).element(boundBy: 1).staticTexts["checklistNotesLabel"].label
    XCTAssert(weekendGetawayNotes.starts(with: notes.prefix(15)))
  }

}
