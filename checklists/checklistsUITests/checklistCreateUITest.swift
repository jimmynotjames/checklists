//
//  checklistCreateUITest.swift
//  checklistsUITests
//
//  Created by Jimmy Ho on 1/2/21.
//

import XCTest

class checklistCreateUITest: XCTestCase {
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
   1a. Create a checklist with 3 Checklist Name, Notes, and 3 items, one item with Item Notes.
   1b. Do it in a way that exercises different ways of adding a new Item.
   2. Then go Back to main page, then tap back in and verify that it's all there, in the right order.
   */
  func testCreateChecklistAndAddItems() {
    let checklistName = "Mindfulness Checklist"
    let checklistNotes = "New year! New checklist!"
    let item1Name = "Gratitude - 1 min"
    let item2Name = "Optional Journaling - 5-10 min"
    let item2NotesLine1 = "The day's events, reactions, feelings, random thoughts, forward-looking intentions?"
    let item2NotesLine2 = "Just write something; don't worry about quality!"
    let item3Name = "Expand love and presence as far as possible."
    let item4Name = "3 deep breaths. Complete!"

    let tablesQuery = app.tables
    var checklistTable = tablesQuery["ChecklistTableView"]
    tablesQuery.buttons["Add new checklist."].tap()

    // Should auto-focus on Checklist Name field
    app.typeText(checklistName)
    app/*@START_MENU_TOKEN@*/ .buttons["done"]/*[[".keyboards",".buttons[\"done\"]",".buttons[\"Done\"]"],[[[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()

    // After tapping done on Checklist Name, should auto-focus on first Item without taps.
    app.typeText(item1Name) // Item 1

    // Create item 2 via tapping Next on keyboard.
    app/*@START_MENU_TOKEN@*/ .buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
      .tap() // Should auto-create Item 2 and auto-focus to write in.
    app.typeText(item2Name) // Item 2

    // Add Item Notes to Item 2
    var cell = checklistTable.children(matching: .cell).element(boundBy: 1)
    cell.textViews["itemNotesTextView"].tap()
    app.typeText(item2NotesLine1)
    app/*@START_MENU_TOKEN@*/ .buttons["Return"]/*[[".keyboards",".buttons[\"return\"]",".buttons[\"Return\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()
    app.typeText(item2NotesLine2)

    // Create Item 3 via Add Button without dismissing keyboard from prior.
    checklistTable.buttons["Add"].tap()
    app.typeText(item3Name)
    app.toolbars["Toolbar"].buttons["Done"].tap()

    // Create Item 4 via Add button after dismissing keyboard from prior.
    checklistTable.buttons["Add"].tap()
    app.typeText(item4Name)
    app.toolbars["Toolbar"].buttons["Done"].tap()

    // Add Checklist Notes back at the top
    checklistTable.textViews["checklistNotesTextView"].tap()
    app.typeText(checklistNotes)

    // Finish and dismiss modal
    app.navigationBars["checklists.ChecklistView"].buttons["Done"].tap()

    // Go back in to Checklist to check stuff.
    tablesQuery/*@START_MENU_TOKEN@*/
      .staticTexts["Mindfulness Checklist"]/*[[".cells.staticTexts[\"Mindfulness Checklist\"]",".staticTexts[\"Mindfulness Checklist\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()

    checklistTable = tablesQuery["ChecklistTableView"]
    XCTAssert((checklistTable.textFields["checklistNameField"].value as? String ?? "") == checklistName)
    XCTAssert((checklistTable.textViews["checklistNotesTextView"].value as? String ?? "") == checklistNotes)

    cell = checklistTable.children(matching: .cell).element(boundBy: 0)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item1Name)

    cell = checklistTable.children(matching: .cell).element(boundBy: 1)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item2Name)
    XCTAssert((cell.textViews["itemNotesTextView"].value as? String ?? "") == (item2NotesLine1 + "\n" + item2NotesLine2))

    // Now remove the notes via Delete key, but keep deleting until some of Item Name is deleted
    let itemNotesTextView = cell.textViews["itemNotesTextView"]
    itemNotesTextView.tap()
    itemNotesTextView.press(forDuration: 0.5)
    app.menuItems["Select All"].tap()
    app.menuItems["Cut"].tap()
    app.toolbars["Toolbar"].buttons["Done"].tap()

    XCTAssert((cell.textViews["itemNotesTextView"].value as? String ?? "").isEmpty)

    cell = checklistTable.children(matching: .cell).element(boundBy: 2)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item3Name)

    cell = checklistTable.children(matching: .cell).element(boundBy: 3)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item4Name)

    // Go back to main page.
    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
  }

  func testCreateChecklist2() {
    app.tables.buttons["Add new checklist."].tap()
    let checklistTable = app.tables["ChecklistTableView"]

    let checklistName = "Mindfulness Checklist"
    let item1Name = "Gratitude - 1 min"
    let item2Name = "Optional Journaling - 5-10 min"
    let item3Name = "Expand love and presence as far as possible."
    let item4Name = "3 deep breaths. Complete!"

    // Should auto-focus on Checklist Name field
    app.typeText(checklistName)
    app/*@START_MENU_TOKEN@*/ .buttons["done"]/*[[".keyboards",".buttons[\"done\"]",".buttons[\"Done\"]"],[[[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()

    // After tapping done on Checklist Name, should auto-focus on first Item without taps.
    app.typeText(item1Name) // Item 1

    // Create Item 3 via Add Button without dismissing keyboard from prior.
    app/*@START_MENU_TOKEN@*/ .buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()
    app.typeText(item3Name)

    // Create Item 4 via Add button after dismissing keyboard from prior.
    app/*@START_MENU_TOKEN@*/ .buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()
    app.typeText(item4Name)
    app.toolbars["Toolbar"].buttons["Done"].tap()

    // Pop back in at Item 1 and insert something.
    checklistTable.children(matching: .cell).element(boundBy: 0).tap()
    app/*@START_MENU_TOKEN@*/ .buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()
    app.typeText(item2Name) // Item 2

    // Check Checklist Name and all the items
    XCTAssert((checklistTable.textFields["checklistNameField"].value as? String ?? "") == checklistName)

    var cell = checklistTable.children(matching: .cell).element(boundBy: 0)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item1Name)

    cell = checklistTable.children(matching: .cell).element(boundBy: 1)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item2Name)

    cell = checklistTable.children(matching: .cell).element(boundBy: 2)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item3Name)

    cell = checklistTable.children(matching: .cell).element(boundBy: 3)
    XCTAssert((cell.textViews["itemNameTextView"].value as? String ?? "") == item4Name)

    // Finish and dismiss modal
    app.navigationBars["checklists.ChecklistView"].buttons["Done"].tap()
  }

  /// Trailing empty Items should be auto-deleted.
  func testItemCleanup() {
    let checklistName = "Mindfulness Checklist"
    let item1Name = "Gratitude - 1 min"

    app.tables.buttons["Add new checklist."].tap()
    let checklistTable = app.tables["ChecklistTableView"]

    // Should auto-focus on Checklist Name field
    app.typeText(checklistName)
    app/*@START_MENU_TOKEN@*/ .buttons["done"]/*[[".keyboards",".buttons[\"done\"]",".buttons[\"Done\"]"],[[[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
      .tap() // Should auto-focus on first Item

    app/*@START_MENU_TOKEN@*/ .buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()
    app.typeText(item1Name)
    app/*@START_MENU_TOKEN@*/ .buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()
    app/*@START_MENU_TOKEN@*/ .buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()

    // Final state: { empty, item1, empty, empty }

    app.toolbars["Toolbar"].buttons["Done"].tap()
    XCTAssert(checklistTable.children(matching: .cell).count == 4)

    // Finish and dismiss modal, go back to check stuff
    app.navigationBars["checklists.ChecklistView"].buttons["Done"].tap()
    app.tables/*@START_MENU_TOKEN@*/
      .staticTexts["Mindfulness Checklist"]/*[[".cells.staticTexts[\"Mindfulness Checklist\"]",".staticTexts[\"Mindfulness Checklist\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()

    // Trailing empty Items should have been removed { empty, item1 }
    XCTAssert(checklistTable.children(matching: .cell).count == 2)
    XCTAssert(checklistTable.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String == item1Name)

    let lowerRightCorner = checklistTable.children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9))
    lowerRightCorner.tap()

    // Remove the text only, leaving Item with empty field.
    let deleteKey = app/*@START_MENU_TOKEN@*/ .keys["delete"]/*[[".keyboards.keys[\"delete\"]",".keys[\"delete\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
    for _ in 1 ... item1Name.count {
      deleteKey.tap()
    }
    app.toolbars["Toolbar"].buttons["Done"].tap()

    // Finish and dismiss modal, go back to check stuff
    app.navigationBars["checklists.ChecklistView"].buttons["Back"].tap()
    app.tables/*@START_MENU_TOKEN@*/
      .staticTexts["Mindfulness Checklist"]/*[[".cells.staticTexts[\"Mindfulness Checklist\"]",".staticTexts[\"Mindfulness Checklist\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()

    XCTAssert(checklistTable.children(matching: .cell).count == 1) // Second item should have been stripped automatically.
  }

  func testCreateBlankChecklist() {
    app.tables.buttons["Add new checklist."].tap()
    app.navigationBars["checklists.ChecklistView"].buttons["Done"].tap()

    XCTAssert(app.tables.children(matching: .cell).element(boundBy: 0).staticTexts["untitled checklist"].exists)
  }

  func testCreateChecklistAndRemoveAllItems() {
    let checklistName = "XYZ"
    app.tables.buttons["Add new checklist."].tap() // Should pull up modal and auto-focus on name. Leave Checklist Name blank.

    app.typeText(checklistName) // Arbitrary Checklist Name
    app/*@START_MENU_TOKEN@*/ .buttons["done"]/*[[".keyboards",".buttons[\"done\"]",".buttons[\"Done\"]"],[[[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
      .tap() // Should auto-focus on first Item after tapping done Checklist Name
    app.typeText("X")
    app/*@START_MENU_TOKEN@*/ .buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()
    app.typeText("Y")

    // Remove all items plus some more delete key tapping for good measure.
    let deleteKey = app/*@START_MENU_TOKEN@*/ .keys["delete"]/*[[".keyboards.keys[\"delete\"]",".keys[\"delete\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
    for _ in 1 ... 8 {
      deleteKey.tap()
    }
    app.navigationBars["checklists.ChecklistView"].buttons["Done"].tap()

    app.staticTexts[checklistName].tap()
    XCTAssert(app.tables["ChecklistTableView"].children(matching: .cell).count == 1)
    XCTAssert(app.tables["ChecklistTableView"].children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"].value as? String == "")
  }

  func testEmojis() {
    let checklistName = "Meditation 🧘🏼"
    let itemName1 = "🧘🏼 10 min"
    let itemName2 = "Express gratitude to universe."
    let itemName3 = "🍳"

    app.tables.buttons["Add new checklist."].tap() // Should pull up modal and auto-focus on name. Leave Checklist Name blank.

    app.typeText(checklistName) // Arbitrary Checklist Name
    app/*@START_MENU_TOKEN@*/ .buttons["done"]/*[[".keyboards",".buttons[\"done\"]",".buttons[\"Done\"]"],[[[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
      .tap() // Should auto-focus on first Item after tapping done Checklist Name
    app.typeText(itemName1)
    app/*@START_MENU_TOKEN@*/ .buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()
    app.typeText(itemName2)
    app/*@START_MENU_TOKEN@*/ .buttons["Next:"]/*[[".keyboards",".buttons[\"next\"]",".buttons[\"Next:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()
    app.typeText(itemName3)

    app.navigationBars["checklists.ChecklistView"].buttons["Done"].tap()
    app.staticTexts[checklistName].tap()

    XCTAssert(app.tables["ChecklistTableView"].children(matching: .cell).count == 3)
    XCTAssert(app.tables["ChecklistTableView"].children(matching: .cell).element(boundBy: 0).textViews["itemNameTextView"].value as? String == itemName1)
    XCTAssert(app.tables["ChecklistTableView"].children(matching: .cell).element(boundBy: 1).textViews["itemNameTextView"].value as? String == itemName2)
    XCTAssert(app.tables["ChecklistTableView"].children(matching: .cell).element(boundBy: 2).textViews["itemNameTextView"].value as? String == itemName3)
  }
}
