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

  /// The detail screen's Back button, found without naming its navigation bar.
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
  /// in the tree beside the list screen's: Back, Reset, Done and `checklist.more` each exist on
  /// exactly one bar at a time. `checklistCreateUITest` follows the same rule.
  var detailBackButton: XCUIElement {
    app.navigationBars.buttons["Back"]
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
}
