//
//  ChecklistItemsUITest.swift
//  checklistsUITests
//
//  Created by Jimmy Ho on 12/31/20.
//

import XCTest

/// Existing items: ticking and resetting, the swipe actions, renaming, and drag reordering.
final class ChecklistItemsUITest: ChecklistDetailUITestCase {
  func testCheckboxesAndReset() {
    // Go into Pre-Trip Checklist. 11 elements, none checked.
    checklistsList.staticTexts["Pre-Trip Checklist"].tap()

    let tablesQuery = app.tables
    XCTAssertTrue(tablesQuery["ChecklistTableView"].waitForExistence(timeout: 5))
    tablesQuery.children(matching: .cell).element(boundBy: 0).buttons["itemCheckbox"].tap()
    tablesQuery.children(matching: .cell).element(boundBy: 5).buttons["itemCheckbox"].tap()

    // Check 2 of the items. Verify that they were checked. Verify status icon updated
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 0).buttons["itemCheckbox"].isSelected == true)
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 5).buttons["itemCheckbox"].isSelected == true)
    assertPercentComplete(tablesQuery["ChecklistTableView"], numCheckedItems: 2, numItems: 11) // Check that circular status icon updated. 2/11 -> 18%

    // Reset checklist. Verify again.
    app.navigationBars.buttons["Reset"].tap()

    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 0).buttons["itemCheckbox"].isSelected == false)
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 5).buttons["itemCheckbox"].isSelected == false)
    assertPercentComplete(tablesQuery["ChecklistTableView"], numCheckedItems: 0, numItems: 11) // Check that circular status icon updated. 0/11 -> 0%

    // Check 2 different items, Verify again. Reset leaves the list at the top, where the last row is
    // below the screen and has no checkbox in the accessibility tree, so scroll down to reach it.
    tablesQuery.children(matching: .cell).element(boundBy: 2).buttons["itemCheckbox"].tap()
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 2).buttons["itemCheckbox"].isSelected == true)
    tablesQuery["ChecklistTableView"].swipeUp()
    tablesQuery.children(matching: .cell).element(boundBy: 10).buttons["itemCheckbox"].tap()
    XCTAssert(tablesQuery.children(matching: .cell).element(boundBy: 10).buttons["itemCheckbox"].isSelected == true)

    // Go Back. Verify circular status is updated on main Checklists page.
    detailBackButton.tap()
    // Check that circular status icon updated on Checklists main page. 2/11 -> 18%
    assertPercentComplete(checklistsList.cells.element(boundBy: 2), numCheckedItems: 2, numItems: 11)
  }

  /// While a field is being typed into, the row just above the keyboard still takes a tap: nothing
  /// rides above the keyboard to swallow it, and Done lives in the navigation bar instead.
  @MainActor func testCheckboxJustAboveKeyboardTakesTapWhileEditing() throws {
    checklistsList.staticTexts["Pre-Trip Checklist"].tap()
    let checklistTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTable.waitForExistence(timeout: 5))

    checklistTable.textViews["checklistNotesTextView"].tap()
    let keyboard = app.keyboards.firstMatch
    XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "Keyboard didn't appear for the notes.")
    XCTAssertTrue(app.checklistEditingDoneButton.waitForExistence(timeout: 5), "The bar didn't swap in its editing Done.")

    // The lowest checkbox still clear of the keyboard: the one a keyboard toolbar would sit over.
    let keyboardTop = keyboard.frame.minY
    let cells = checklistTable.children(matching: .cell)
    let lowestCheckbox = (0 ..< cells.count)
      .map { cells.element(boundBy: $0).buttons["itemCheckbox"] }
      .filter { $0.exists && $0.frame.maxY <= keyboardTop }
      .max { $0.frame.maxY < $1.frame.maxY }
    let checkbox = try XCTUnwrap(lowestCheckbox, "No checkbox sits above the keyboard.")
    XCTAssertFalse(checkbox.isSelected)

    checkbox.tap()
    XCTAssertTrue(checkbox.wait(for: \.isSelected, toEqual: true, timeout: 5), "The tap above the keyboard didn't reach the checkbox.")
  }

  func testItemDeletion() {
    checklistsList.staticTexts["Morning Routine"].tap()

    let tablesQuery = app.tables
    XCTAssertTrue(tablesQuery["ChecklistTableView"].waitForExistence(timeout: 5))

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

  /// The item swipe's other action. Delete keeps the outer edge, so both must be reachable after
  /// one swipe, and this one must act without a confirmation.
  func testItemDuplication() {
    checklistsList.staticTexts["Morning Routine"].tap()

    let tablesQuery = app.tables
    XCTAssertTrue(tablesQuery["ChecklistTableView"].waitForExistence(timeout: 5))

    guard let itemName = tablesQuery.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String else {
      XCTFail("Item name text view value was not a String"); return
    }

    assertPercentComplete(tablesQuery["ChecklistTableView"], numCheckedItems: 5, numItems: 6) // Check circular status icon initial status. 5/6

    let cell = tablesQuery.children(matching: .cell).element(boundBy: 1)
    cell.swipeLeft() // "Yoga/meditation"
    let duplicateAction = tablesQuery.buttons["Duplicate"]
    XCTAssertTrue(duplicateAction.waitForExistence(timeout: 5), "Swipe-to-duplicate action didn't appear.")
    duplicateAction.tap()
    // Nothing is confirmed and nothing is presented — the copy is simply there.
    XCTAssertFalse(app.alerts.firstMatch.exists, "Duplicating shouldn't raise a confirmation.")

    // The copy lands directly below the original, one row further down.
    guard let copiedName = tablesQuery.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as? String else {
      XCTFail("Item name text view value was not a String"); return
    }
    XCTAssertEqual(copiedName, itemName, "The copy should carry the original's name, unchanged.")
    assertPercentComplete(tablesQuery["ChecklistTableView"], numCheckedItems: 5, numItems: 7) // Check circular status icon updated. 5/7
  }

  func testChecklistEditItemName() throws {
    checklistsList.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTableView.waitForExistence(timeout: 5))

    let item2NameTextView = checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"]
    let item2Name = try XCTUnwrap(item2NameTextView.value as? String)
    item2NameTextView.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()

    let n = 11
    item2NameTextView.pressDeleteKey(n)

    var trimmedName = try XCTUnwrap(item2NameTextView.value as? String)
    XCTAssert(item2Name.prefix(item2Name.count - n) == trimmedName)

    // For good measure, back out, and go back in again, and check again.
    detailBackButton.tap()
    checklistsList.staticTexts["Morning Routine"].tap()
    trimmedName = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String)
    XCTAssert(item2Name.prefix(item2Name.count - n) == trimmedName)
  }

  func testChecklistReordering1() throws {
    checklistsList.staticTexts["Weekend Getaway Essentials"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTableView.waitForExistence(timeout: 5))

    // Go to last Item and move to index 8.
    checklistTableView.swipeUp()
    let cells = checklistTableView.children(matching: .cell)
    let item12Name = try XCTUnwrap(cells.element(boundBy: 11).textViews["itemNameTextView"].value as? String)

    dragRow(cells.element(boundBy: 11), onto: cells.element(boundBy: 7))

    // Now the original last item should now be at index 7.
    waitForItemName(item12Name, atRow: 7, in: checklistTableView)

    // For good measure, go Back to main page, then back into Checklist, and see if all elements are still ordered correctly.
    // NOTE: the nav bar title only shows the checklist name once the table view is scrolled past a
    // threshold (ChecklistViewController.scrollViewDidScroll), so the bar's identifier is sometimes
    // the checklist's name and sometimes the view controller's default — see `detailBackButton`,
    // which sidesteps the question.
    detailBackButton.tap()
    checklistsList.staticTexts["Weekend Getaway Essentials"].tap()
    checklistTableView.swipeUp()
    let item7Value = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 7).textViews["itemNameTextView"].value as? String)
    XCTAssert(item12Name == item7Value)
  }

  func testChecklistReordering2() throws {
    checklistsList.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTableView.waitForExistence(timeout: 5))

    // Go to last Item and move to index 0.
    let cells = checklistTableView.children(matching: .cell)
    let fromName = try XCTUnwrap(cells.element(boundBy: 5).textViews["itemNameTextView"].value as? String)
    let item1Name = try XCTUnwrap(cells.element(boundBy: 0).textViews["itemNameTextView"].value as? String)
    let item2Name = try XCTUnwrap(cells.element(boundBy: 1).textViews["itemNameTextView"].value as? String)

    dragRow(cells.element(boundBy: 5), onto: cells.element(boundBy: 0))
    waitForItemName(fromName, atRow: 0, in: checklistTableView)

    var atIndex0 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"].value as? String)
    var atIndex1 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String)
    var atIndex2 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as? String)
    XCTAssert(fromName == atIndex0) // Now the original last item should now be at index 7.
    XCTAssert(item1Name == atIndex1) // The original item 1 should now be shifted down to item 2.
    XCTAssert(item2Name == atIndex2) // The original item 2 should now be shifted down to item 3.

    // For good measure, go Back to main page, then back into Checklist, and see if all elements are still ordered correctly.
    detailBackButton.tap()
    checklistsList.staticTexts["Morning Routine"].tap()
    atIndex0 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"].value as? String)
    atIndex1 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String)
    atIndex2 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as? String)
    XCTAssert(fromName == atIndex0) // Now the original last item should now be at index 7.
    XCTAssert(item1Name == atIndex1) // The original item 1 should now be shifted down to item 2.
    XCTAssert(item2Name == atIndex2) // The original item 2 should now be shifted down to item 3.
  }
}
