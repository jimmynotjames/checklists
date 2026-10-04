//
//  ChecklistReorderModeTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing
import UIKit

/// Covers Reorder Items mode on the checklist screen and the VoiceOver move actions on its rows.
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
      let firstSection = try #require(harness.viewController.makeMoreMenu().children.first as? UIMenu)
      let entry = try #require(firstSection.children.first as? UIAction)
      #expect(entry.title == ChecklistViewController.reorderItemsMenuTitle)
      #expect(firstSection.children.count == 1)
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
      let barItems = controller.navigationItem.rightBarButtonItems ?? []
      #expect(barItems.count == 1)
      #expect(barItems.first?.accessibilityIdentifier == "checklist.reorderDone")
      #expect(barItems.first?.title == CommonStrings.done)
      #expect(controller.navigationItem.leftBarButtonItem == nil)

      #expect(!harness.header.nameTextField.isEnabled)
      #expect(!harness.header.notesTextView.isEditable)
      let footer = try #require(harness.table.tableFooterView)
      #expect(!footer.isUserInteractionEnabled)

      let rows = harness.table.visibleCells.compactMap { $0 as? ItemTableViewCell }
      #expect(rows.count == 3)
      #expect(rows.allSatisfy { !$0.itemContentView.isUserInteractionEnabled })

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
      let backButton = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
      controller.navigationItem.leftBarButtonItem = backButton
      let original = try #require(controller.navigationItem.rightBarButtonItems)

      controller.enterReorderMode()
      controller.setEditing(false, animated: false)

      #expect(!controller.isReordering)
      #expect(controller.navigationItem.rightBarButtonItems == original)
      #expect(controller.navigationItem.leftBarButtonItem === backButton)
      #expect(harness.header.nameTextField.isEnabled)
      let rows = harness.table.visibleCells.compactMap { $0 as? ItemTableViewCell }
      #expect(rows.allSatisfy(\.itemContentView.isUserInteractionEnabled))
      #expect(controller.tableView(harness.table, trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0)) != nil)
    }
  }

  /// `configureNavigationBar` would put Reset back here, since `isNewChecklist` reads false by the
  /// time the mode can be opened; restoring what was saved keeps the sheet's own Done.
  @Test("leaving on the create sheet puts back its Done, not Reset")
  func leavingOnTheCreateSheetKeepsItsDone() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems, isNewChecklist: true) { harness in
      let controller = harness.viewController
      let original = try #require(controller.navigationItem.rightBarButtonItems)
      controller.isNewChecklist = false

      controller.enterReorderMode()
      controller.setEditing(false, animated: false)

      #expect(controller.navigationItem.rightBarButtonItems == original)
    }
  }

  @Test("entering twice still leaves with the original bar")
  func enteringTwiceIsHarmless() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let controller = harness.viewController
      let original = try #require(controller.navigationItem.rightBarButtonItems)

      controller.setEditing(true, animated: false)
      controller.setEditing(true, animated: false)
      controller.setEditing(false, animated: false)

      #expect(controller.navigationItem.rightBarButtonItems == original)
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
        to: IndexPath(row: 0, section: 0)
      )

      #expect(try harness.persistedItemNames() == ["Eggs", "Milk", "Bread"])
    }
  }

  // MARK: - VoiceOver moves

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

  @Test("the rows carry their moves as VoiceOver actions")
  func rowsCarryMoveActions() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let row = try #require(harness.table.cellForRow(at: IndexPath(row: 0, section: 0)) as? ItemTableViewCell)
      let names = row.itemContentView.accessibilityFocusTarget.accessibilityCustomActions?.map(\.name)
      #expect(names == [
        ChecklistViewController.moveActionTitle(for: .down),
        ChecklistViewController.moveActionTitle(for: .bottom),
      ])
    }
  }

  @Test(
    "each move is saved and announced",
    arguments: [
      (ChecklistMoveAction.up, 1, ["Bread", "Milk", "Eggs"], 1),
      (.down, 1, ["Milk", "Eggs", "Bread"], 3),
      (.top, 2, ["Eggs", "Milk", "Bread"], 1),
      (.bottom, 0, ["Bread", "Eggs", "Milk"], 3),
    ]
  )
  func moveIsSavedAndAnnounced(action: ChecklistMoveAction, from index: Int, expected: [String], position: Int) throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      var announcements: [String] = []
      harness.viewController.moveFeedback = { _, announcement in announcements.append(announcement) }
      let id = harness.checklist.items[index].id

      #expect(harness.viewController.move(itemWithID: id, action))

      #expect(try harness.persistedItemNames() == expected)
      #expect(announcements == [ChecklistViewController.movedToPositionAnnouncement(position: position, count: 3)])
    }
  }

  @Test("a move that cannot be saved reports failure and announces nothing")
  func failedMoveIsNotAnnounced() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      struct SaveFailed: Error {}
      var announced = false
      harness.viewController.moveFeedback = { _, _ in announced = true }
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
      #expect(try harness.persistedItemNames() == ["Milk", "Bread", "Eggs"])
    }
  }
}
