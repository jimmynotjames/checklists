//
//  ChecklistDetailUITestCase.swift
//  checklistsUITests
//
//  Created by Jimmy Ho on 12/31/20.
//

import XCTest

/// Shared launch and queries for the checklist-screen UI test classes. Add no `test*` methods here:
/// XCTest runs inherited tests in every subclass, relaunching the app for each.
class ChecklistDetailUITestCase: XCTestCase {
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
  var checklistsList: XCUIElementQuery {
    app.collectionViews
  }

  /// The detail screen's Back button, found without naming its navigation bar. It is the SwiftUI
  /// stack's own back button, so it reads as the list's title; `BackButton` is the identifier UIKit
  /// gives it in every language.
  ///
  /// **Never name the detail screen's navigation bar in a query.** Its identifier is whichever of
  /// the checklist name / the view controller's default ("checklists.ChecklistView") happens to
  /// apply: `ChecklistViewController.scrollViewDidScroll` only shows the title once the table is
  /// scrolled past a threshold, so the identifier flips between the two depending on scroll
  /// position — and under the SwiftUI `NavigationStack` the title survives a reorder drag / row
  /// insertion. A query naming the bar therefore passes or fails
  /// on how far the table happened to scroll, which is the difference between a green suite and an
  /// intermittent "No matches found for … IN identifiers".
  ///
  /// Matching on the button alone is immune to that, and stays unambiguous even with a sheet's bar
  /// in the tree beside the list screen's: Back, `checklist.reset`, Done and `checklist.more` each exist on
  /// exactly one bar at a time. `checklistCreateUITest` follows the same rule.
  var detailBackButton: XCUIElement {
    app.navigationBars.buttons["BackButton"]
  }

  /// Long-presses `row` and drops it on `target`, the way a user drag-reorders a ChecklistScreen row.
  ///
  /// The press is on the row's checkbox, the one part of a row that is neither an editable text view
  /// nor a screen edge. The name and notes have a long press of their own, which starts editing
  /// instead of lifting the row, and which of the two wins comes down to timing. The edge margins are
  /// taken by the back swipe on the left and the grabbable scroll indicator on the right. The
  /// checkbox doesn't toggle: the lift cancels its touch, and failing that the finger lifts far
  /// outside it.
  ///
  /// The press also opens the row's context menu; moving the finger lifts the row out of it into
  /// the drag. As in `checklistsUITests.testChecklistReordering`, a drag that crosses the menu
  /// releases on one of its entries instead of moving the row.
  ///
  /// The hold is long and the move slow because the first lift after launch can take longer than a
  /// user's half-second; moving before it lands cancels the long press, and nothing is dragged. The
  /// closing hold lets the table settle on the destination row before the drop.
  ///
  /// Then waits for row `index` of `table` to show `name`, the dragged item's. A drop moves its row
  /// only once the dragged item has loaded (`ChecklistViewController.tableView(_:performDropWith:)`),
  /// which can land after the gesture's idle wait.
  ///
  /// Drags once more if the first left the order as it was. Under heavy simulator load the row can
  /// lift and then settle back in place without the drag ever starting, which leaves nothing to undo.
  /// A drop in the wrong place still fails.
  func dragRow(
    _ row: XCUIElement,
    named name: String,
    onto target: XCUIElement,
    landingAtRow index: Int,
    in table: XCUIElement,
    file: StaticString = #filePath,
    line: UInt = #line,
  ) {
    let center = CGVector(dx: 0.5, dy: 0.5)
    let drag = {
      row.buttons["itemCheckbox"].coordinate(withNormalizedOffset: center)
        .press(forDuration: 1.5, thenDragTo: target.coordinate(withNormalizedOffset: center), withVelocity: .slow, thenHoldForDuration: 0.5)
      XCTAssertFalse(self.app.keyboards.firstMatch.exists, "The press began editing instead of lifting the row.", file: file, line: line)
    }
    let landed = table.children(matching: .cell).element(boundBy: index).textViews["itemNameTextView"]
    // A fresh expectation per wait: one already waited on can't be waited on again.
    let landedShowsName = {
      XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", name), object: landed)], timeout: 5)
    }
    drag()
    if landedShowsName() != .completed, row.textViews["itemNameTextView"].value as? String == name {
      XCTContext.runActivity(named: "The row didn't move; dragging it once more.") { _ in }
      drag()
    }
    XCTAssertEqual(
      landedShowsName(), .completed,
      "Row \(index) shows \"\(landed.value as? String ?? "nil")\", not \"\(name)\".",
      file: file,
      line: line,
    )
  }

  /// Mirrors `CircularPercentStatusIcon.accessibilityValueText(forPercentageComplete:)`, which the
  /// UI test target cannot call — it runs in its own process and does not link the app module.
  ///
  /// The percentage goes through the same `.percent` format style rather than being interpolated
  /// with a literal `%`: the separator and the symbol's side are locale-dependent ("18%", "18 %",
  /// "%18").
  func percentCompleteString(numCheckedItems: Int, numItems: Int) -> String {
    let percent = (Double(numCheckedItems) / Double(numItems))
      .formatted(.percent.precision(.fractionLength(0)))
    return "Checklist \(percent) complete"
  }

  /// Asserts that `parentElement` contains the circular status icon's accessibility element with the
  /// expected percent-complete value.
  ///
  /// Waits rather than checking `.exists` outright: several call sites assert immediately after a
  /// Back tap, and the destination cell's status icon isn't necessarily laid out the instant the pop
  /// transition starts.
  func assertPercentComplete(
    _ parentElement: XCUIElement,
    numCheckedItems: Int,
    numItems: Int,
    file: StaticString = #filePath,
    line: UInt = #line,
  ) {
    let expected = percentCompleteString(numCheckedItems: numCheckedItems, numItems: numItems)
    let element = parentElement.otherElements[expected]
    XCTAssertTrue(
      element.waitForExistence(timeout: 5),
      "No percent-complete element found with accessibility value \"\(expected)\"",
      file: file,
      line: line,
    )
    XCTAssertEqual(element.value as? String, expected, file: file, line: line)
  }
}
