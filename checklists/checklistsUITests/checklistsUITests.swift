//
//  checklistsUITests.swift
//  checklistsUITests
//
//  Created by Jimmy Ho on 5/7/19.
//

import XCTest

class checklistsUITests: XCTestCase {
  var app: XCUIApplication!

  override func setUp() {
    continueAfterFailure = false

    // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
    app = XCUIApplication()
    app.launchArguments = ["-UITests1"]
    app.launch()
    XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5), "Main checklists list did not appear after launch.")
  }

  func testChecklistDeletion() {
    // See checklistUITest.checklistsList.
    let listQuery = app.collectionViews
    listQuery.staticTexts["Weekend Getaway Essentials"].swipeLeft()
    // The swipe action lives in the row, but scoping to `app` keeps this working regardless of
    // where the collection view hangs the revealed action button.
    let deleteAction = app.buttons["Delete"]
    XCTAssertTrue(deleteAction.waitForExistence(timeout: 5), "Swipe-to-delete action didn't appear.")
    deleteAction.tap()
    let confirmDelete = app.alerts.buttons["Delete"]
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete confirmation alert didn't appear.")
    confirmDelete.tap()

    let staticText1 = listQuery.staticTexts["Morning Routine"]
    let staticText2 = listQuery.staticTexts["Weekend Getaway Essentials"]
    let staticText3 = listQuery.staticTexts["Pre-Trip Checklist"]
    XCTAssert(staticText1.waitForExistence(timeout: 5))
    XCTAssert(staticText2.exists == false)
    XCTAssert(staticText3.exists)
  }

  func testChecklistReordering() {
    let text1 = app.staticTexts["Morning Routine"]
    let text2 = app.staticTexts["Weekend Getaway Essentials"]
    let text3 = app.staticTexts["Pre-Trip Checklist"]
    // Drag row 1 onto row 2, for the ordering 2, 1, 3.
    //
    // Two changes from the UIKit gesture this replaces. SwiftUI's `.onMove` needs a longer press to
    // lift the row than the table view's reorder control did, plus a slow drag and a hold at the end
    // so the list settles on the drop target before the touch lifts. And the drop target is row 2
    // rather than row 3: the old gesture nominally dragged onto row 3 but only ever moved the row one
    // slot, whereas SwiftUI honours the full drag and lands it at the end (2, 3, 1) — so the target
    // now says what the assertions below have always meant.
    text1.press(forDuration: 1.0, thenDragTo: text2, withVelocity: .slow, thenHoldForDuration: 1.0)

    XCTAssertGreaterThan(text1.frame.origin.y, text2.frame.origin.y, "Row 1 should have moved below row 2.")
    XCTAssertGreaterThan(text3.frame.origin.y, text1.frame.origin.y, "Row 3 should still be below row 1.")
  }
}
