//
//  ChecklistReorderModeTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing
import UIKit

/// Covers Reorder Items mode on the checklist screen and the VoiceOver actions on its rows.
///
/// `.serialized` for the reason `ChecklistMenuActionTests` gives: the harness controller registers a
/// `RemoteChangeObserver`.
@Suite("Checklist Reorder Items mode", .serialized)
struct ChecklistReorderModeTests {
  private static let threeItems: [(name: String, isChecked: Bool)] = [("Milk", false), ("Bread", true), ("Eggs", false)]

  // MARK: - The menu entry

  @Test("Reorder Items opens the menu, on a saved checklist and on the create sheet", arguments: [false, true])
  func reorderItemsLeadsTheMenu(isNewChecklist: Bool) throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems, isNewChecklist: isNewChecklist) { harness in
      #expect(harness.viewController.bar.menuSections.first == [.reorderItems])
    }
  }

  // MARK: - Entering and leaving

  @Test("entering clears the bar down to Done and freezes everything but the rows' handles")
  func enteringFreezesTheScreen() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let controller = harness.viewController
      controller.enterReorderMode()

      #expect(controller.isReordering)
      #expect(harness.table.isEditing)
      // `.reordering` is also what hides Back; see `ChecklistScreen`.
      #expect(controller.bar.mode == .reordering)
      #expect(controller.bar.trailingItems.isEmpty)
      #expect(controller.bar.pinnedItem == .reorderDone)

      #expect(!harness.header.nameTextField.isEnabled)
      #expect(!harness.header.notesTextView.isEditable)
      let footer = try #require(harness.table.tableFooterView as? AddItemButtonTableFooterView)
      #expect(!footer.isUserInteractionEnabled)
      #expect(footer.contentView.alpha == 0)

      let rows = harness.table.visibleCells.compactMap { $0 as? ItemTableViewCell }
      #expect(rows.count == 3)
      #expect(rows.allSatisfy { !$0.itemContentView.isUserInteractionEnabled })
      #expect(rows.allSatisfy { !$0.itemContentView.checkboxButton.isEnabled })

      let firstRow = IndexPath(row: 0, section: 0)
      #expect(controller.tableView(harness.table, editingStyleForRowAt: firstRow) == .none)
      #expect(!controller.tableView(harness.table, shouldIndentWhileEditingRowAt: firstRow))
      #expect(controller.tableView(harness.table, trailingSwipeActionsConfigurationForRowAt: firstRow) == nil)

      #expect(harness.analytics.count(of: AnalyticsEvent.checklistReorderModeEntered) == 1)
    }
  }

  @Test("leaving puts back the bar it found, Reset and the menu")
  func leavingRestoresTheBar() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let controller = harness.viewController
      controller.enterReorderMode()
      controller.setEditing(false, animated: false)

      #expect(!controller.isReordering)
      #expect(controller.bar.mode == .idle)
      #expect(controller.bar.trailingItems == [.more, .primary])
      #expect(controller.bar.pinnedItem == nil)
      #expect(harness.header.nameTextField.isEnabled)
      let footer = try #require(harness.table.tableFooterView as? AddItemButtonTableFooterView)
      #expect(footer.isUserInteractionEnabled)
      #expect(footer.contentView.alpha == 1)
      let rows = harness.table.visibleCells.compactMap { $0 as? ItemTableViewCell }
      let allInteractive = rows.allSatisfy(\.itemContentView.isUserInteractionEnabled)
      #expect(allInteractive)
      let allCheckboxesEnabled = rows.allSatisfy(\.itemContentView.checkboxButton.isEnabled)
      #expect(allCheckboxesEnabled)
      #expect(controller.tableView(harness.table, trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0)) != nil)
    }
  }

  /// `isNewChecklist` reads false by the time the mode can be opened; the bar's own copy, taken at
  /// load, keeps the sheet's Done.
  @Test("leaving on the create sheet puts back its Done, not Reset")
  func leavingOnTheCreateSheetKeepsItsDone() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems, isNewChecklist: true) { harness in
      let controller = harness.viewController
      controller.isNewChecklist = false

      controller.enterReorderMode()
      controller.setEditing(false, animated: false)

      #expect(controller.bar.trailingItems == [.more])
      #expect(controller.bar.pinnedItem == .primary)
    }
  }

  @Test("entering twice still leaves with the original bar")
  func enteringTwiceIsHarmless() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let controller = harness.viewController
      controller.setEditing(true, animated: false)
      controller.setEditing(true, animated: false)
      controller.setEditing(false, animated: false)

      #expect(controller.bar.mode == .idle)
      #expect(controller.bar.trailingItems == [.more, .primary])
    }
  }

  /// The table puts its footer view back to full opacity when it animates a row move; the Add
  /// button must stay hidden regardless.
  @Test("the Add button stays hidden when the table resets its footer during a move")
  func addButtonStaysHiddenThroughAMove() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      harness.viewController.setEditing(true, animated: false)
      let footer = try #require(harness.table.tableFooterView as? AddItemButtonTableFooterView)

      footer.alpha = 1
      harness.viewController.tableView(
        harness.table,
        moveRowAt: IndexPath(row: 2, section: 0),
        to: IndexPath(row: 0, section: 0),
      )

      #expect(footer.contentView.alpha == 0)
      #expect(!footer.isUserInteractionEnabled)
    }
  }

  @Test("the VoiceOver escape gesture leaves the mode, and does nothing outside it")
  func escapeLeavesTheMode() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let controller = harness.viewController
      #expect(!controller.accessibilityPerformEscape())

      controller.setEditing(true, animated: false)
      #expect(controller.accessibilityPerformEscape())
      #expect(!controller.isReordering)
    }
  }

  @Test("a remote merge's reload keeps the rows frozen")
  func remoteMergeKeepsRowsFrozen() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      harness.viewController.setEditing(true, animated: false)

      harness.viewController.handleRemoteChange()
      harness.table.layoutIfNeeded()

      let rows = harness.table.visibleCells.compactMap { $0 as? ItemTableViewCell }
      #expect(!rows.isEmpty)
      #expect(rows.allSatisfy { !$0.itemContentView.isUserInteractionEnabled })
    }
  }

  @Test("a checkbox tap that slips through in the mode changes nothing")
  func checkboxIsIgnoredInTheMode() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      harness.viewController.setEditing(true, animated: false)
      let row = try #require(harness.table.cellForRow(at: IndexPath(row: 0, section: 0)) as? ItemTableViewCell)

      harness.viewController.itemContentViewCheckboxButtonTapped(row.itemContentView)

      #expect(harness.checklist.items[0].status == .unchecked)
    }
  }

  @Test("a handle drag in the mode is saved")
  func handleDragIsSaved() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      harness.viewController.setEditing(true, animated: false)

      harness.viewController.tableView(
        harness.table,
        moveRowAt: IndexPath(row: 2, section: 0),
        to: IndexPath(row: 0, section: 0),
      )

      let saved = try harness.persistedItemNames()
      #expect(saved == ["Eggs", "Milk", "Bread"])
    }
  }

  // MARK: - VoiceOver actions

  @Test("each row offers only the moves that go somewhere")
  func availableMovesAtTheEdges() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let items = harness.checklist.items
      let controller = harness.viewController
      #expect(controller.availableMoves(for: items[0]) == [.down, .bottom])
      #expect(controller.availableMoves(for: items[1]) == [.up, .down, .top, .bottom])
      #expect(controller.availableMoves(for: items[2]) == [.up, .top])
    }
  }

  @Test("the rows carry their moves, Duplicate and Delete as VoiceOver actions")
  func rowsCarryMoveActions() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let row = try #require(harness.table.cellForRow(at: IndexPath(row: 0, section: 0)) as? ItemTableViewCell)
      let names = row.itemContentView.accessibilityFocusTarget.accessibilityCustomActions?.map(\.name)
      #expect(names == [
        ChecklistViewController.moveActionTitle(for: .down),
        ChecklistViewController.moveActionTitle(for: .bottom),
        CommonStrings.duplicate,
        CommonStrings.delete,
      ])
    }
  }

  @Test("Reorder Items mode drops Duplicate and Delete with the swipe actions, and leaving brings them back")
  func reorderModeDropsDuplicateAndDelete() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let row = try #require(harness.table.cellForRow(at: IndexPath(row: 0, section: 0)) as? ItemTableViewCell)
      @MainActor func actionNames() -> [String] {
        row.itemContentView.accessibilityFocusTarget.accessibilityCustomActions?.map(\.name) ?? []
      }
      harness.viewController.setEditing(true, animated: false)
      let reordering = actionNames()
      #expect(reordering == [
        ChecklistViewController.moveActionTitle(for: .down),
        ChecklistViewController.moveActionTitle(for: .bottom),
      ])
      harness.viewController.setEditing(false, animated: false)
      let afterwards = actionNames()
      #expect(afterwards.suffix(2) == [CommonStrings.duplicate, CommonStrings.delete])
    }
  }

  @Test("the VoiceOver Delete and Duplicate actions act on their own row")
  func deleteAndDuplicateActionsWork() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      @MainActor func action(named name: String, onRow index: Int) throws -> UIAccessibilityCustomAction {
        let row = try #require(harness.table.cellForRow(at: IndexPath(row: index, section: 0)) as? ItemTableViewCell)
        let actions = row.itemContentView.accessibilityFocusTarget.accessibilityCustomActions ?? []
        return try #require(actions.first { $0.name == name })
      }

      let duplicate = try action(named: CommonStrings.duplicate, onRow: 1)
      #expect(duplicate.actionHandler?(duplicate) == true)
      let afterDuplicate = try harness.persistedItemNames()
      #expect(afterDuplicate == ["Milk", "Bread", "Bread", "Eggs"])

      let delete = try action(named: CommonStrings.delete, onRow: 0)
      #expect(delete.actionHandler?(delete) == true)
      let afterDelete = try harness.persistedItemNames()
      #expect(afterDelete == ["Bread", "Bread", "Eggs"])
    }
  }

  @Test(
    "each move is saved and announced",
    arguments: [
      (ChecklistMoveAction.up, 1, ["Bread", "Milk", "Eggs"], 1),
      (.down, 1, ["Milk", "Eggs", "Bread"], 3),
      (.top, 2, ["Eggs", "Milk", "Bread"], 1),
      (.bottom, 0, ["Bread", "Eggs", "Milk"], 3),
    ],
  )
  func moveIsSavedAndAnnounced(action: ChecklistMoveAction, from index: Int, expected: [String], position: Int) throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      var announcements: [String?] = []
      harness.viewController.accessibilityFeedback = { _, announcement in announcements.append(announcement) }
      let id = harness.checklist.items[index].id

      #expect(harness.viewController.move(itemWithID: id, action))

      let saved = try harness.persistedItemNames()
      #expect(saved == expected)
      #expect(announcements == [ChecklistViewController.movedToPositionAnnouncement(position: position, count: 3)])
    }
  }

  @Test("a move that cannot be saved reports failure and announces nothing")
  func failedMoveIsNotAnnounced() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      struct SaveFailed: Error {}
      var announced = false
      harness.viewController.accessibilityFeedback = { _, _ in announced = true }
      harness.viewController.saveItemMove = { _, _, _ in throw SaveFailed() }
      let id = harness.checklist.items[0].id

      #expect(!harness.viewController.move(itemWithID: id, .down))
      #expect(!announced)
    }
  }

  @Test("a move that goes nowhere does nothing")
  func moveOffTheEndDoesNothing() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let id = harness.checklist.items[0].id
      #expect(!harness.viewController.move(itemWithID: id, .up))
      let saved = try harness.persistedItemNames()
      #expect(saved == ["Milk", "Bread", "Eggs"])
    }
  }
}
