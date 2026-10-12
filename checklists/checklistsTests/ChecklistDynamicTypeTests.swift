//
//  ChecklistDynamicTypeTests.swift
//  checklistsTests
//

@testable import checklists
import Testing
import UIKit

/// Covers the checklist screen following a text-size change while it is open: the fonts rescale
/// themselves, and these check that what the table measured follows them.
/// `.serialized` — same `RemoteChangeObserver` reason as `ChecklistMenuActionTests`.
@Suite("Checklist screen at a changed text size", .serialized)
struct ChecklistDynamicTypeTests {
  /// One layout pass carries the new size down to the views and re-measures the header and footer.
  private func changeTextSize(to category: UIContentSizeCategory, in harness: ChecklistScreenHarness.Context) {
    harness.viewController.traitOverrides.preferredContentSizeCategory = category
    harness.viewController.view.layoutIfNeeded()
  }

  @Test("the header, first row, footer, and title threshold grow with the text size")
  func layoutFollowsTextSize() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      let firstRow = IndexPath(row: 0, section: 0)
      let headerHeight = harness.header.frame.height
      let rowHeight = harness.table.rectForRow(at: firstRow).height
      let threshold = harness.viewController.titleThresholdY
      let footerHeight = try #require(harness.table.tableFooterView).frame.height

      changeTextSize(to: .accessibilityExtraExtraExtraLarge, in: harness)

      #expect(harness.header.frame.height > headerHeight)
      #expect(harness.table.rectForRow(at: firstRow).height > rowHeight)
      #expect(harness.viewController.titleThresholdY > threshold)
      #expect(try #require(harness.table.tableFooterView).frame.height > footerHeight)
      #expect(harness.table.rectForRow(at: firstRow).minY >= harness.header.frame.maxY, "The first row clears the header.")
    }
  }

  @Test("the checklist name stops growing at its cap")
  func nameIsCapped() throws {
    try ChecklistScreenHarness.withController { harness in
      changeTextSize(to: .accessibilityExtraExtraExtraLarge, in: harness)
      let font = try #require(harness.header.nameTextField.font)
      #expect(font.pointSize == 45.0)
      #expect(harness.header.nameTextField.frame.height >= ceil(font.lineHeight))
    }
  }
}
