//
//  checklistsUITests.swift
//  checklistsUITests
//
//  Created by Jimmy Ho on 5/7/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import XCTest

// IMPORTANT NOTE: Running these tests will clear/reset the persisted database on the app.
class checklistsUITests: XCTestCase {

  var app: XCUIApplication!

  override func setUp() {
    continueAfterFailure = false

    // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
    app = XCUIApplication()
    app.launchArguments = ["-UITests1"]
    app.launch()
  }

  override func tearDown() {
    
  }

  func testChecklistDeletion() {

    let tablesQuery = app.tables
    tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Weekend Getaway Essentials"]/*[[".cells.staticTexts[\"Weekend Getaway Essentials\"]",".staticTexts[\"Weekend Getaway Essentials\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.swipeLeft()
    tablesQuery/*@START_MENU_TOKEN@*/.buttons["Delete"]/*[[".cells.buttons[\"Delete\"]",".buttons[\"Delete\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
    app.alerts.scrollViews.otherElements.buttons["Delete"].tap()

    let staticText1 = tablesQuery.staticTexts["Morning Routine"]
    let staticText2 = tablesQuery.staticTexts["Weekend Getaway Essentials"]
    let staticText3 = tablesQuery.staticTexts["Pre-Trip Checklist"]
    XCTAssert(staticText1.exists)
    XCTAssert(staticText2.exists == false)
    XCTAssert(staticText3.exists)

    // Use recording to get started writing UI tests.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
  }

  func testChecklistReordering() {
    let text1 = app.staticTexts["Morning Routine"]
    let text2 = app.staticTexts["Weekend Getaway Essentials"]
    let text3 = app.staticTexts["Pre-Trip Checklist"]
    text1.press(forDuration: 0.75, thenDragTo: text3) // Results in ordering: 2, 1, 3

    XCTAssert(text1.frame.origin.y > text2.frame.origin.y)
    XCTAssert(text3.frame.origin.y > text1.frame.origin.y)
  }
}
