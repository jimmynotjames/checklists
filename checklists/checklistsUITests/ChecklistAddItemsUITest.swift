//
//  ChecklistAddItemsUITest.swift
//  checklistsUITests
//
//  Created by Jimmy Ho on 12/31/20.
//

import XCTest

/// Adding and removing items from the keyboard and the Add button.
final class ChecklistAddItemsUITest: ChecklistDetailUITestCase {
  /**
   You can create an Item by tapping Next on keyboard and remove one by tapping Delete
   on an empty Item.
   */
  func testAddDeleteItemsWithCursor() throws {
    checklistsList.staticTexts["Pre-Trip Checklist"].tap()

    let checklisttableviewTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklisttableviewTable.waitForExistence(timeout: 5))
    let itemNameTextView1a = checklisttableviewTable.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"]
    itemNameTextView1a.tap()
    let itemNameTextView1aValue = try XCTUnwrap(itemNameTextView1a.value as? String)

    let itemNameTextView2aValue = try XCTUnwrap(checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as? String)

    // Add some items with Next key
    app.pressReturnKey()
    app.typeText("X")

    app.pressReturnKey()
    app.typeText("Y")

    app.pressReturnKey()
    app.typeText("Z")

    app.pressReturnKey()

    // Remove those items with Delete key and nothing else.
    app.pressDeleteKey(7)
    app.toolbars["Toolbar"].buttons["Done"].tap()

    // Test that original state was restored.
    let itemNameTextView1bValue = try XCTUnwrap(checklisttableviewTable.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String)
    XCTAssert(itemNameTextView1aValue == itemNameTextView1bValue)

    var itemNameTextView2bValue = try XCTUnwrap(checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as? String)
    XCTAssert(itemNameTextView2aValue == itemNameTextView2bValue)

    // Add notes to an Item, then delete the notes and keep tapping Delete. Should not spill into Name field.
    checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].tap()
    let itemNotesTextView2 = checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNotesTextView"]
    itemNotesTextView2.tap()
    app.typeText("Make sure key in planter.")
    itemNotesTextView2.pressDeleteKey(30)
    app.toolbars["Toolbar"].buttons["Done"].tap()

    // Check that Name field still preserved.
    itemNameTextView2bValue = try XCTUnwrap(checklisttableviewTable.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as? String)
    XCTAssert(itemNameTextView2aValue == itemNameTextView2bValue)
  }

  func testAddItemsAtEnd() throws {
    let newItemName1 = "Walk the dog"
    let newItemName2 = "Turn off coffee maker"

    checklistsList.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTableView.waitForExistence(timeout: 5))

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

    // Whether the nav bar is titled here depends on where `insertNewItem` leaves the table scrolled;
    // `detailBackButton` finds the button without naming the bar. See the note on that property.
    detailBackButton.tap()
    // Check that circular status icon updated on Checklists page.
    assertPercentComplete(checklistsList.cells.element(boundBy: 0), numCheckedItems: numCheckedItems, numItems: numItems + 1)
    checklistsList.staticTexts["Morning Routine"].tap()

    // Check that changes persisted.
    XCTAssert(checklistTableView.children(matching: .cell).count == numItems + 1)
    XCTAssert(checklistTableView.children(matching: .cell).element(boundBy: numItems).textViews["itemNameTextView"].value as? String == newItemName1)
    assertPercentComplete(checklistTableView, numCheckedItems: numCheckedItems, numItems: numItems + 1) // Check that circular status icon updated.

    // Now add something at end using keyboard Return key ("Next") key.
    let lastItemNameTextView = checklistTableView.children(matching: .cell).element(boundBy: numItems).textViews["itemNameTextView"]
    lastItemNameTextView.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()

    lastItemNameTextView.pressReturnKey()
    app.typeText(newItemName2)
    app.toolbars["Toolbar"].buttons["Done"].tap()

    XCTAssert(checklistTableView.children(matching: .cell).count == numItems + 2)
    assertPercentComplete(checklistTableView, numCheckedItems: numCheckedItems, numItems: numItems + 2) // Check that circular status icon updated.
    var lastItemName = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: numItems + 1).textViews["itemNameTextView"].value as? String)
    XCTAssert(lastItemName == newItemName2)

    // Go back to main page, back into Checklist, and check again.
    detailBackButton.tap()
    // Check that circular status icon updated on Checklists page.
    assertPercentComplete(checklistsList.cells.element(boundBy: 0), numCheckedItems: numCheckedItems, numItems: numItems + 2)
    checklistsList.staticTexts["Morning Routine"].tap()

    XCTAssert(checklistTableView.children(matching: .cell).count == numItems + 2)
    assertPercentComplete(checklistTableView, numCheckedItems: numCheckedItems, numItems: numItems + 2) // Check that circular status icon updated.
    lastItemName = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: numItems + 1).textViews["itemNameTextView"].value as? String)
    XCTAssert(lastItemName == newItemName2)
  }

  /**
   1. Turn the phone to landscape, where the keyboard covers most of a short window.
   2. Go to the "Morning Routine" Checklist and add an item at the end with the Add button.
   3. Check that the item being typed into sits above the keyboard, not behind it.
   */
  @MainActor func testNewItemStaysAboveKeyboardInLandscape() {
    rotateToLandscapeAndSettle()
    addTeardownBlock { XCUIDevice.shared.orientation = .portrait }

    checklistsList.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTableView.waitForExistence(timeout: 5))
    let numItems = checklistTableView.children(matching: .cell).count

    checklistTableView.swipeUp()
    checklistTableView.buttons["Add"].tap()
    app.typeText("Pack sunglasses")

    let keyboard = app.keyboards.firstMatch
    XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "Keyboard didn't appear for the new item.")
    let newItem = checklistTableView.children(matching: .cell).element(boundBy: numItems)
    XCTAssertTrue(newItem.waitForExistence(timeout: 5), "New item row didn't appear.")
    // The Done bar rides above the keyboard and covers rows just the same.
    let doneBar = app.toolbars.containing(.button, identifier: "Done").firstMatch
    let coveredFrom = doneBar.exists ? min(doneBar.frame.minY, keyboard.frame.minY) : keyboard.frame.minY
    XCTAssertLessThanOrEqual(
      newItem.textViews["itemNameTextView"].frame.maxY,
      coveredFrom,
      "The item being typed into is hidden behind the keyboard."
    )
  }

  /// Turns the phone to landscape and returns once the rotation animation has finished.
  ///
  /// XCTest's own idle wait returns while the window is still mid-turn, and a tap synthesized then
  /// is aimed at the half-rotated window and lost. The window's accessibility frame passes through
  /// the in-between sizes, so wait for it to reach the portrait frame turned on its side.
  @MainActor private func rotateToLandscapeAndSettle() {
    let window = app.windows.firstMatch
    let portrait = window.frame
    XCUIDevice.shared.orientation = .landscapeLeft
    let landscape = CGRect(x: 0, y: 0, width: portrait.height, height: portrait.width)
    XCTAssertTrue(
      window.wait(for: \.frame, toEqual: landscape, timeout: 5),
      "The window didn't settle in landscape."
    )
  }
}
