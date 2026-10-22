//
//  ChecklistAccessibilityFeedbackTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import Testing
import UIKit

/// What deleting, duplicating and resetting on the checklist screen tells VoiceOver: where it moves
/// and what it says. Observed through `accessibilityFeedback`; the real posts need VoiceOver running.
@Suite("Checklist screen VoiceOver feedback", .serialized)
struct ChecklistAccessibilityFeedbackTests {
  private static let threeItems: [(name: String, isChecked: Bool)] = [("Milk", false), ("Bread", true), ("Eggs", false)]

  private struct Feedback {
    let focus: NSObject?
    let announcement: String?
  }

  @Test(
    "the row that takes the deleted one's place gets VoiceOver, else the one above it",
    arguments: [(1, 1), (2, 1), (0, 0)]
  )
  func deleteFocusesTheNeighbour(deleted index: Int, focused neighbour: Int) throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      var feedback: [Feedback] = []
      harness.viewController.accessibilityFeedback = { feedback.append(Feedback(focus: $0, announcement: $1)) }

      harness.viewController.deleteItem(at: index, announcesResult: true)

      let expectedFocus = harness.viewController.rowFocusTarget(at: neighbour)
      #expect(expectedFocus != nil)
      #expect(feedback.count == 1)
      #expect(feedback.first?.focus === expectedFocus)
      #expect(feedback.first?.announcement == ChecklistViewController.itemDeletedAnnouncement)
    }
  }

  @Test("deleting the only item moves VoiceOver to the Add button")
  func deletingTheLastItemFocusesAdd() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      var feedback: [Feedback] = []
      harness.viewController.accessibilityFeedback = { feedback.append(Feedback(focus: $0, announcement: $1)) }

      harness.viewController.deleteItem(at: 0, announcesResult: true)

      let addButton = (harness.table.tableFooterView as? AddItemButtonTableFooterView)?.addButton
      #expect(addButton != nil)
      #expect(feedback.first?.focus === addButton)
    }
  }

  @Test("backspace's delete leaves VoiceOver to the editing that follows")
  func unannouncedDeleteSaysNothing() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      var announced = false
      harness.viewController.accessibilityFeedback = { _, _ in announced = true }

      harness.viewController.deleteItem(at: 1)

      #expect(!announced)
    }
  }

  @Test("duplicating announces and leaves VoiceOver on the original")
  func duplicateAnnouncesWithoutMovingFocus() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      var feedback: [Feedback] = []
      harness.viewController.accessibilityFeedback = { feedback.append(Feedback(focus: $0, announcement: $1)) }

      harness.viewController.duplicateItem(at: 1)

      #expect(feedback.count == 1)
      #expect(feedback.first?.focus == nil)
      #expect(feedback.first?.announcement == ChecklistViewController.itemDuplicatedAnnouncement)
    }
  }

  @Test("Reset announces only when it unticked something", arguments: [true, false])
  func resetAnnouncesOnlyAChange(hasCheckedItem: Bool) throws {
    let items = [("Milk", false), ("Bread", hasCheckedItem)]
    try ChecklistScreenHarness.withController(items: items) { harness in
      var announcements: [String?] = []
      harness.viewController.accessibilityFeedback = { _, announcement in announcements.append(announcement) }

      harness.viewController.resetButtonTapped()

      #expect(announcements == (hasCheckedItem ? [ChecklistViewController.allItemsUncheckedAnnouncement] : []))
    }
  }

  @Test("Delete Checked Items announces the count and moves VoiceOver to the first row left")
  func deleteCheckedItemsAnnouncesTheCount() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", true), ("Bread", true), ("Eggs", false)]) { harness in
      var feedback: [Feedback] = []
      harness.viewController.accessibilityFeedback = { feedback.append(Feedback(focus: $0, announcement: $1)) }

      harness.viewController.deleteCheckedItems()

      let firstRow = harness.viewController.rowFocusTarget(at: 0)
      #expect(firstRow != nil)
      #expect(feedback.first?.focus === firstRow)
      #expect(feedback.first?.announcement == ChecklistViewController.checkedItemsDeletedAnnouncement(count: 2))
    }
  }
}

@Suite("Checklist menu VoiceOver feedback", .serialized)
struct ChecklistMenuFeedbackTests {
  @Test("tapping a checked-items entry with nothing ticked announces the notice")
  func noCheckedItemsNoticeIsAnnounced() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      var announcements: [String?] = []
      harness.viewController.accessibilityFeedback = { _, announcement in announcements.append(announcement) }

      harness.viewController.checkedItemsEntryTapped(.copy)

      #expect(announcements == [ChecklistViewController.noItemsCheckedNotice])
    }
  }
}

@Suite("Focus after a deletion")
struct DeletionFocusTests {
  @Test(
    "picks the row that slid up, else the one above, else none",
    arguments: [
      (0, 2, 0 as Int?),
      (1, 2, 1),
      (2, 2, 1),
      (0, 0, nil),
    ]
  )
  func neighbour(removed index: Int, remaining: Int, expected: Int?) {
    #expect(DeletionFocus.neighbourIndex(afterRemoving: index, remainingCount: remaining) == expected)
  }
}

/// Reorder Items mode swaps the bar item VoiceOver was on, so the screen points VoiceOver at its
/// replacement.
@Suite("Reorder Items mode VoiceOver focus", .serialized)
struct ReorderModeFocusTests {
  @Test("VoiceOver goes to Done in the mode, and back to ⋯ once it ends")
  func focusMovesWithTheMode() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      let controller = harness.viewController
      let more = try #require(controller.moreBarButtonItem)
      var focused: [NSObject?] = []
      controller.reorderModeFocusDelay = nil
      controller.accessibilityFeedback = { focus, _ in focused.append(focus) }

      controller.setEditing(true, animated: false)
      let done = try #require(focused.last as? UIBarButtonItem)
      #expect(done.accessibilityIdentifier == "checklist.reorderDone")

      controller.setEditing(false, animated: false)
      #expect(focused.count == 2)
      let afterwards = focused.compactMap(\.self).last
      #expect(afterwards === more)
    }
  }
}

/// The bar shows no title until the name scrolls under it, so the name field is the screen's heading.
@Suite("Checklist screen heading", .serialized)
struct ChecklistHeadingTests {
  @Test("the name field is a heading")
  func nameFieldIsAHeading() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      #expect(harness.header.nameTextField.accessibilityTraits.contains(.header))
    }
  }
}
