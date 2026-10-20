//
//  ChecklistEditingDoneTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import Testing
import UIKit

/// Covers the navigation bar's editing Done: the slot beside the overflow menu while a field on the
/// checklist screen is being typed into.
///
/// `.serialized` for the reason `ChecklistMenuActionTests` gives: the harness controller registers a
/// `RemoteChangeObserver`.
@Suite("Checklist editing Done", .serialized)
struct ChecklistEditingDoneTests {
  private static let threeItems: [(name: String, isChecked: Bool)] = [("Milk", false), ("Bread", true), ("Eggs", false)]

  /// The slot beside the overflow menu, which sits at the outer edge.
  private func slotItem(_ controller: ChecklistViewController) -> UIBarButtonItem? {
    controller.navigationItem.rightBarButtonItems?.last
  }

  private func isEditingDone(_ item: UIBarButtonItem?) -> Bool {
    item?.accessibilityIdentifier == "checklist.editingDone"
  }

  /// Gives the slot's deferred hand-back its turn of the run loop.
  private func settle() {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
  }

  private func firstRow(_ harness: ChecklistScreenHarness.Context) throws -> ItemTableViewCell {
    try #require(harness.table.cellForRow(at: IndexPath(row: 0, section: 0)) as? ItemTableViewCell)
  }

  @Test("the slot holds Reset beside the menu while nothing is being typed")
  func idleBarHoldsReset() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let items = harness.viewController.navigationItem.rightBarButtonItems ?? []
      #expect(items.count == 2)
      #expect(items.first?.accessibilityIdentifier == "checklist.more")
      #expect(items.last?.title == ChecklistViewController.resetButtonTitle)
    }
  }

  @Test("typing in the name, the notes or an item lends the slot to the editing Done, and ending puts Reset back", arguments: ["name", "notes", "item"])
  func typingSwapsTheSlot(field: String) throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let controller = harness.viewController
      switch field {
      case "name": harness.header.nameTextField.becomeFirstResponder()
      case "notes": harness.header.notesTextView.becomeFirstResponder()
      default: try firstRow(harness).itemContentView.startEditing()
      }

      #expect(isEditingDone(slotItem(controller)))
      #expect(controller.navigationItem.rightBarButtonItems?.first?.accessibilityIdentifier == "checklist.more")

      controller.view.endEditing(true)
      settle()

      #expect(slotItem(controller)?.title == ChecklistViewController.resetButtonTitle)
    }
  }

  @Test("the create sheet's Done gives way to the editing Done and comes back")
  func createSheetDoneComesBack() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems, isNewChecklist: true) { harness in
      let controller = harness.viewController
      #expect(slotItem(controller)?.accessibilityIdentifier == "checklist.done")

      harness.header.nameTextField.becomeFirstResponder()
      #expect(isEditingDone(slotItem(controller)))

      controller.view.endEditing(true)
      settle()
      #expect(slotItem(controller)?.accessibilityIdentifier == "checklist.done")
    }
  }

  @Test("tapping the editing Done ends typing and keeps what was typed")
  func editingDoneCommits() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let nameField = harness.header.nameTextField
      nameField.becomeFirstResponder()
      nameField.text = "Pantry"

      harness.viewController.editingDoneTapped()
      settle()

      #expect(!nameField.isFirstResponder)
      #expect(harness.checklist.name == "Pantry")
      #expect(slotItem(harness.viewController)?.title == ChecklistViewController.resetButtonTitle)
    }
  }

  /// Return hands focus from one row to a new one below it; the slot must not blink to Reset and
  /// back on the way.
  @Test("Return on an item's name keeps the editing Done throughout the hand-off")
  func returnHandOffKeepsTheEditingDone() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let controller = harness.viewController
      let row = try firstRow(harness)
      row.itemContentView.startEditing()

      controller.itemContentViewDidReturnOnNameField(row.itemContentView)
      var slotsSeen: [Bool] = []
      for _ in 0 ..< 40 {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
        slotsSeen.append(isEditingDone(slotItem(controller)))
      }

      #expect(harness.checklist.items.count == 4)
      let neverReset = slotsSeen.allSatisfy(\.self)
      #expect(neverReset)
    }
  }

  @Test("Reorder Items mode entered mid-edit leaves with Reset, not the editing Done")
  func reorderMidEditRestoresReset() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let controller = harness.viewController
      harness.header.nameTextField.becomeFirstResponder()

      controller.enterReorderMode()
      settle()
      let reorderBar = controller.navigationItem.rightBarButtonItems ?? []
      #expect(reorderBar.count == 1)
      #expect(reorderBar.first?.accessibilityIdentifier == "checklist.reorderDone")

      controller.setEditing(false, animated: false)
      let items = controller.navigationItem.rightBarButtonItems ?? []
      #expect(items.count == 2)
      #expect(items.last?.title == ChecklistViewController.resetButtonTitle)
    }
  }
}
