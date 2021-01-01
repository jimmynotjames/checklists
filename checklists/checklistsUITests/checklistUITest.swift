//
//  checklistUITest.swift
//  checklistsUITests
//
//  Created by Jimmy Ho on 12/31/20.
//  Copyright © 2020 Jimmy Ho. All rights reserved.
//

import XCTest

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
}
