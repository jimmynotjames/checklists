//
//  KeyboardShortcutsUITest.swift
//  checklistsUITests
//

import XCTest

/// Hardware-keyboard shortcuts on ChecklistsView and ChecklistScreen. `typeKey` sends the key
/// whether or not the software keyboard is on screen.
///
/// ⌘⌫ and Esc have no test here: `typeKey` delivers letters but not Delete or Escape on the
/// simulator, with or without ⌘ (a plain Delete into a focused field changes nothing). They are
/// checked by hand on a hardware keyboard.
final class KeyboardShortcutsUITest: ChecklistDetailUITestCase {
  /// **These tests must always run with animations on, on CI too. Don't remove this override.**
  ///
  /// With animations off (CI's `FORCE_ANIMATIONS=off`, see `TestAnimationsOverride`), a shortcut
  /// sent right after a screen change is sometimes lost: ⌘N after Back or on ChecklistsView fails
  /// to open the create sheet, and ⌘D's copy doesn't take the cursor. That reproduces locally
  /// (`TEST_RUNNER_FORCE_ANIMATIONS=off make focused-tests ONLY=checklistsUITests/KeyboardShortcutsUITest`),
  /// not just on CI. With animations on they pass and stay fast, since none of them hits the
  /// 60-second idle stalls the switch exists for.
  override static var keepsAnimations: Bool {
    true
  }

  private var checklistTable: XCUIElement {
    app.tables["ChecklistTableView"]
  }

  private var itemCells: XCUIElementQuery {
    checklistTable.children(matching: .cell)
  }

  private func itemName(at index: Int) -> XCUIElement {
    itemCells.element(boundBy: index).textViews["itemNameTextView"]
  }

  /// Opens Morning Routine and, given `index`, starts typing in that item's name.
  private func openMorningRoutine(typingIn index: Int? = nil) {
    checklistsList.staticTexts["Morning Routine"].tap()
    XCTAssertTrue(checklistTable.waitForExistence(timeout: 5))
    XCTAssertEqual(itemCells.count, 6)
    if let index {
      itemName(at: index).tapForKeyboardFocus()
    }
  }

  // MARK: - ChecklistScreen

  /// With nothing being typed, ⌘N still reaches the screen. It adds an item and types in it, and
  /// doesn't also make a checklist from the screen underneath; back there, ⌘N makes one again.
  func testCommandNAddsItemNotChecklist() {
    let checklistCount = checklistsList.cells.count
    openMorningRoutine()

    app.typeKey("n", modifierFlags: .command)
    XCTAssertTrue(itemCells.element(boundBy: 6).waitForExistence(timeout: 5), "⌘N didn't add an item.")
    XCTAssertTrue(itemName(at: 6).waitForKeyboardFocus(), "The new item didn't take the cursor.")

    app.tapChecklistEditingDone()
    detailBackButton.tap()
    XCTAssertTrue(checklistsList.cells.firstMatch.waitForExistence(timeout: 5))
    XCTAssertEqual(checklistsList.cells.count, checklistCount, "⌘N on ChecklistScreen also made a checklist.")

    app.typeKey("n", modifierFlags: .command)
    XCTAssertTrue(
      app.textFields["checklistNameField"].waitForKeyboardFocus(),
      "⌘N after going Back didn't open the create sheet.",
    )
  }

  @MainActor func testCommandKTogglesItemBeingTyped() {
    openMorningRoutine(typingIn: 1)
    let checkbox = itemCells.element(boundBy: 1).buttons["itemCheckbox"]
    let wasChecked = checkbox.isSelected

    app.typeKey("k", modifierFlags: .command)
    XCTAssertTrue(checkbox.wait(for: \.isSelected, toEqual: !wasChecked, timeout: 5), "⌘K didn't toggle the item.")
    XCTAssertTrue(itemName(at: 1).waitForKeyboardFocus(), "⌘K took the cursor out of the item.")
  }

  func testCommandDDuplicatesAndTypesInTheCopy() throws {
    openMorningRoutine(typingIn: 1)
    let name = try XCTUnwrap(itemName(at: 1).value as? String)

    app.typeKey("d", modifierFlags: .command)
    XCTAssertTrue(itemCells.element(boundBy: 6).waitForExistence(timeout: 5), "⌘D didn't add a copy.")
    XCTAssertEqual(itemName(at: 2).value as? String, name, "The copy isn't directly below the original.")
    XCTAssertTrue(itemName(at: 2).waitForKeyboardFocus(), "The cursor didn't move into the copy.")
  }

  // MARK: - ChecklistsView

  func testCommandNOnChecklistsViewOpensCreateSheet() {
    app.typeKey("n", modifierFlags: .command)
    XCTAssertTrue(
      app.textFields["checklistNameField"].waitForKeyboardFocus(),
      "⌘N didn't open the create sheet.",
    )
  }
}
