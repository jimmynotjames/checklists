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

    let app = XCUIApplication()
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
}
