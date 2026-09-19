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
    XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5), "Main checklists list did not appear after launch.")
  }

  override func tearDownWithError() throws {}

  /// The main checklists list is a SwiftUI `List`, which XCUITest exposes as a collection view.
  /// The checklist *detail* screen behind it is still a UIKit table view (`ChecklistTableView`),
  /// so `app.tables` still addresses that screen and only that screen.
  private var checklistsList: XCUIElementQuery {
    app.collectionViews
  }

  /// The detail screen's Back button, found without naming its navigation bar.
  ///
  /// The bar's identifier is whichever of the checklist name / the view controller's default
  /// ("checklists.ChecklistView") happens to apply: `ChecklistViewController.scrollViewDidScroll`
  /// only shows the title once the table is scrolled past a threshold, so the identifier flips
  /// between the two depending on scroll position — and under the SwiftUI `NavigationStack` the
  /// title now survives a reorder drag / row insertion where it used to be cleared. Only one
  /// navigation bar is in the tree while the detail screen is up, so matching on the button alone
  /// is both simpler and immune to that.
  private var detailBackButton: XCUIElement {
    app.navigationBars.buttons["Back"]
  }

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

    checklistsList.staticTexts["Morning Routine"].tap()

    let tablesQuery = app.tables
    let checklistNameField = tablesQuery.textFields["Checklist Name: "]
    XCTAssertTrue(checklistNameField.waitForExistence(timeout: 5))
    checklistNameField.tap()
    checklistNameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
    checklistNameField.typeText("Ritual")

    let checklistNotesTextView = tablesQuery.textViews["Checklist Notes: "]
    checklistNotesTextView.tap()
    checklistNotesTextView.typeText(newChecklistNotes)

    detailBackButton.tap()
    // The main list's notes preview label has an explicit accessibilityIdentifier
    // ("checklistNotesLabel", set on every row), so it no longer matches by its rendered text via the
    // bare `staticTexts[...]` subscript the way an unlabeled element would — look it up by identifier
    // and assert on its `.label` instead.
    let morningRoutineNotesLabel = checklistsList.cells.element(boundBy: 0).staticTexts["checklistNotesLabel"]
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
    // Go into Pre-Trip Checklist. 11 elements, none checked.
    checklistsList.staticTexts["Pre-Trip Checklist"].tap()

    let tablesQuery = app.tables
    XCTAssertTrue(tablesQuery["ChecklistTableView"].waitForExistence(timeout: 5))
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
    detailBackButton.tap()
    // Check that circular status icon updated on Checklists main page. 2/11 -> 18%
    assertPercentComplete(checklistsList.cells.element(boundBy: 2), numCheckedItems: 2, numItems: 11)
  }

  /// A checklist with no history still shows both caption lines, reading "Never".
  func testHistoryCaptionReadsNeverOnFreshChecklist() {
    // Every UI-test launch gets a freshly seeded in-memory store, so nothing has been ticked yet.
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    let caption = app.staticTexts["checklistMetadataLabel"]
    XCTAssertTrue(caption.waitForExistence(timeout: 5))
    XCTAssertEqual(caption.label, "Last updated: Never. Last completed: Never")
  }

  /// The create sheet shows no caption: there, both lines could only ever read "Never".
  func testHistoryCaptionAbsentOnNewChecklistSheet() {
    app.buttons["Add new checklist."].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    XCTAssertFalse(
      app.staticTexts["checklistMetadataLabel"].exists,
      "The create sheet should not carry a caption that can only say Never."
    )
  }

  /// Ticking an item rewrites the caption without leaving the screen.
  func testHistoryCaptionUpdatesWhileOnScreen() {
    checklistsList.staticTexts["Morning Routine"].tap()
    let tablesQuery = app.tables
    XCTAssertTrue(tablesQuery["ChecklistTableView"].waitForExistence(timeout: 5))

    let caption = app.staticTexts["checklistMetadataLabel"]
    XCTAssertTrue(caption.waitForExistence(timeout: 5))
    XCTAssertTrue(caption.label.hasPrefix("Last updated: Never"))

    tablesQuery.children(matching: .cell).element(boundBy: 0).buttons["Checkbox"].tap()

    // An expectation rather than reading `.label` straight after the tap: a bare read forces a
    // snapshot that blocks until the app goes idle, with no deadline of its own.
    let captionChanged = expectation(
      for: NSPredicate(format: "NOT (label BEGINSWITH %@)", "Last updated: Never"),
      evaluatedWith: caption
    )
    captionChanged.expectationDescription = "the caption tracks a tick live, without reopening the screen"
    wait(for: [captionChanged], timeout: 5)
  }

  /**
   1. Complete "Morning Routine" by checking its one remaining item.
   2. Leave and come back, so the caption is rebuilt from the store rather than refreshed in place.
   3. Verify both lines are there.
   4. Reset, leave and come back again: the completion line outlives the reset.
   */
  func testHistoryCaptionAfterCompletingAndResetting() {
    checklistsList.staticTexts["Morning Routine"].tap()
    let tablesQuery = app.tables
    XCTAssertTrue(tablesQuery["ChecklistTableView"].waitForExistence(timeout: 5))

    // Tap every unchecked box rather than a hardcoded row, so the test survives a fixture change.
    let cells = tablesQuery.children(matching: .cell)
    for index in 0 ..< cells.count {
      let checkbox = cells.element(boundBy: index).buttons["Checkbox"]
      if checkbox.exists, !checkbox.isSelected {
        checkbox.tap()
      }
    }

    detailBackButton.tap()
    checklistsList.staticTexts["Morning Routine"].tap()

    let caption = app.staticTexts["checklistMetadataLabel"]
    XCTAssertTrue(caption.waitForExistence(timeout: 5), "A completed checklist should show a caption.")
    // The label reads as two sentences; the dates themselves follow the runner's locale, so only
    // the prefixes are asserted.
    XCTAssertTrue(caption.label.hasPrefix("Last updated: "), "Unexpected caption: \(caption.label)")
    XCTAssertTrue(caption.label.contains("Last completed: "), "Unexpected caption: \(caption.label)")
    XCTAssertFalse(caption.label.hasSuffix("Never"), "Unexpected caption: \(caption.label)")

    app.navigationBars.buttons["Reset"].tap()
    detailBackButton.tap()
    checklistsList.staticTexts["Morning Routine"].tap()

    let captionAfterReset = app.staticTexts["checklistMetadataLabel"]
    XCTAssertTrue(captionAfterReset.waitForExistence(timeout: 5))
    XCTAssertTrue(
      captionAfterReset.label.contains("Last completed: "),
      "Reset clears the checkmarks, not the record that a run finished. Got: \(captionAfterReset.label)"
    )
    XCTAssertFalse(
      captionAfterReset.label.hasSuffix("Never"),
      "Reset must not erase the completion date. Got: \(captionAfterReset.label)"
    )
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
    checklistsList.staticTexts["Weekend Getaway Essentials"].tap()

    let checklistTableView = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTableView.waitForExistence(timeout: 5))
    let checklistnotestextviewTextView = checklistTableView.textViews["checklistNotesTextView"]
    checklistnotestextviewTextView.tap()

    let notes = loremIspum + "\n" + loremIspum
    app.typeText(notes)

    app.toolbars["Toolbar"].buttons["Done"].tap()

    checklistTableView.swipeUp()

    detailBackButton.tap()

    let weekendGetawayNotesLabel = checklistsList.cells.element(boundBy: 1).staticTexts["checklistNotesLabel"]
    XCTAssertTrue(weekendGetawayNotesLabel.waitForExistence(timeout: 5), "Notes label didn't appear on the main list after the pop-back animation.")
    XCTAssert(weekendGetawayNotesLabel.label.starts(with: notes.prefix(15)))
  }

  /// Long notes must not push the list underneath the header.
  ///
  /// Backing out and re-entering is the point: typing grows the header through `textViewDidChange`,
  /// so this only shows on a screen that opens with long notes already saved.
  func testLongNotesDoNotCoverTheFirstItem() {
    checklistsList.staticTexts["Morning Routine"].tap()
    let tablesQuery = app.tables
    XCTAssertTrue(tablesQuery["ChecklistTableView"].waitForExistence(timeout: 5))

    tablesQuery.textViews["checklistNotesTextView"].tap()
    app.typeText((1 ... 6).map { "Notes line \($0)." }.joined(separator: "\n"))
    app.toolbars["Toolbar"].buttons["Done"].tap()

    detailBackButton.tap()
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(tablesQuery["ChecklistTableView"].waitForExistence(timeout: 5))

    let firstCheckbox = tablesQuery.children(matching: .cell).element(boundBy: 0).buttons["Checkbox"]
    XCTAssertTrue(firstCheckbox.waitForExistence(timeout: 5))
    XCTAssertTrue(firstCheckbox.isHittable, "The first item is sitting underneath the header.")
  }

  func testChecklistReordering1() throws {
    checklistsList.staticTexts["Weekend Getaway Essentials"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTableView.waitForExistence(timeout: 5))

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
    // threshold (ChecklistViewController.scrollViewDidScroll), so the bar's identifier is sometimes
    // the checklist's name and sometimes the view controller's default — see `detailBackButton`,
    // which sidesteps the question.
    detailBackButton.tap()
    checklistsList.staticTexts["Weekend Getaway Essentials"].tap()
    checklistTableView.swipeUp()
    item7Value = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 7).textViews["itemNameTextView"].value as? String)
    XCTAssert(item12Name == item7Value)
  }

  func testChecklistReordering2() throws {
    checklistsList.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTableView.waitForExistence(timeout: 5))

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
    detailBackButton.tap()
    checklistsList.staticTexts["Morning Routine"].tap()
    atIndex0 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"].value as? String)
    atIndex1 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String)
    atIndex2 = try XCTUnwrap(checklistTableView.children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as? String)
    XCTAssert(fromName == atIndex0) // Now the original last item should now be at index 7.
    XCTAssert(item1Name == atIndex1) // The original item 1 should now be shifted down to item 2.
    XCTAssert(item2Name == atIndex2) // The original item 2 should now be shifted down to item 3.
  }

  func testChecklistEditItemName() throws {
    checklistsList.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTableView.waitForExistence(timeout: 5))

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
    detailBackButton.tap()
    checklistsList.staticTexts["Morning Routine"].tap()
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

    app/*@START_MENU_TOKEN@*/ .buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()
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

  // MARK: - Deleting from the overflow menu

  /// Opens the detail screen's overflow menu and taps its one entry, leaving the confirmation up.
  private func tapDeleteChecklistEntry() {
    let moreButton = app.navigationBars.buttons["More"]
    XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "Overflow menu button didn't appear.")
    moreButton.tap()
    // A `UIMenu` entry surfaces as a loose button rather than inside the navigation bar.
    let deleteEntry = app.buttons["Delete Checklist"]
    XCTAssertTrue(deleteEntry.waitForExistence(timeout: 5), "Delete Checklist menu entry didn't appear.")
    deleteEntry.tap()
  }

  func testDeleteChecklistFromDetailMenu() {
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    tapDeleteChecklistEntry()
    let confirmDelete = app.alerts.buttons["Delete"]
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete confirmation alert didn't appear.")
    confirmDelete.tap()

    // Both halves of the delete: the screen goes away *and* the row is gone from the list behind it.
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForNonExistence(timeout: 5), "The detail screen didn't dismiss.")
    XCTAssertTrue(checklistsList.staticTexts["Pre-Trip Checklist"].waitForExistence(timeout: 5))
    XCTAssertFalse(checklistsList.staticTexts["Morning Routine"].exists)
  }

  func testCancellingDeleteKeepsTheChecklist() {
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5))

    tapDeleteChecklistEntry()
    let cancel = app.alerts.buttons["Cancel"]
    XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Delete confirmation alert didn't appear.")
    cancel.tap()

    XCTAssertTrue(app.tables["ChecklistTableView"].exists, "Cancelling should leave the screen up.")
    detailBackButton.tap()
    XCTAssertTrue(checklistsList.staticTexts["Morning Routine"].waitForExistence(timeout: 5))
  }

  /// Deleting straight out of an active edit, with the keyboard still up. The name field's delegate
  /// writes on resignation, so this is the case that catches a commit landing after the record is
  /// gone — and the trailing-blank-item trim that runs once the screen has left.
  func testDeleteChecklistWhileEditingItsName() {
    checklistsList.staticTexts["Morning Routine"].tap()
    let checklistTableView = app.tables["ChecklistTableView"]
    XCTAssertTrue(checklistTableView.waitForExistence(timeout: 5))

    let nameField = checklistTableView.textFields["checklistNameField"]
    nameField.tap()
    app.typeText(" edited")

    tapDeleteChecklistEntry()
    let confirmDelete = app.alerts.buttons["Delete"]
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete confirmation alert didn't appear.")
    confirmDelete.tap()

    XCTAssertTrue(checklistsList.staticTexts["Pre-Trip Checklist"].waitForExistence(timeout: 5))
    XCTAssertFalse(checklistsList.staticTexts["Morning Routine"].exists)
    XCTAssertFalse(checklistsList.staticTexts["Morning Routine edited"].exists)
  }
}
