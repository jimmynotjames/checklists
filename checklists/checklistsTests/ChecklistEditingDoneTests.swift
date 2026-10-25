//
//  ChecklistEditingDoneTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import Testing
import UIKit

/// Covers the navigation bar's editing Done: added at the outer edge while a field on the checklist
/// screen is being typed into, as Notes does it.
///
/// `.serialized` for the reason `ChecklistMenuActionTests` gives: the harness controller registers a
/// `RemoteChangeObserver`.
@Suite("Checklist editing Done", .serialized)
struct ChecklistEditingDoneTests {
  private static let threeItems: [(name: String, isChecked: Bool)] = [("Milk", false), ("Bread", true), ("Eggs", false)]

  /// The trailing bar items, outer edge first: the pinned item, if any, then the rest. Each is named
  /// by its identifier, or "Reset" for Reset, which carries none.
  private func bar(_ controller: ChecklistViewController) -> [String] {
    let pinned = controller.pinnedTrailingItem.map { [$0] } ?? []
    return (pinned + (controller.navigationItem.rightBarButtonItems ?? [])).map {
      $0.title == ChecklistViewController.resetButtonTitle ? "Reset" : $0.accessibilityIdentifier ?? "?"
    }
  }

  private static let pushedIdle = ["checklist.more", "Reset"]
  private static let pushedTyping = ["checklist.editingDone", "checklist.more", "Reset"]
  private static let createIdle = ["checklist.done", "checklist.more"]
  private static let createTyping = ["checklist.editingDone", "checklist.more"]

  /// Gives the deferred bar update its turn of the run loop.
  private func settle() {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
  }

  private func firstRow(_ harness: ChecklistScreenHarness.Context) throws -> ItemTableViewCell {
    try #require(harness.table.cellForRow(at: IndexPath(row: 0, section: 0)) as? ItemTableViewCell)
  }

  @Test("Reset sits on the title side of the menu while nothing is being typed")
  func idleBar() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      #expect(bar(harness.viewController) == Self.pushedIdle)
    }
  }

  @Test("typing in the name, the notes or an item adds the editing Done at the outer edge, and ending takes it away", arguments: ["name", "notes", "item"])
  func typingAddsTheEditingDone(field: String) throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let controller = harness.viewController
      switch field {
      case "name": harness.header.nameTextField.becomeFirstResponder()
      case "notes": harness.header.notesTextView.becomeFirstResponder()
      default: try firstRow(harness).itemContentView.startEditing()
      }

      #expect(bar(controller) == Self.pushedTyping)

      controller.view.endEditing(true)
      settle()

      #expect(bar(controller) == Self.pushedIdle)
    }
  }

  @Test("on the create sheet, the editing Done stands in for the sheet's own at the outer edge")
  func createSheetDoneComesBack() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems, isNewChecklist: true) { harness in
      let controller = harness.viewController
      #expect(bar(controller) == Self.createIdle)

      harness.header.nameTextField.becomeFirstResponder()
      #expect(bar(controller) == Self.createTyping)

      controller.view.endEditing(true)
      settle()
      #expect(bar(controller) == Self.createIdle)
    }
  }

  @Test("the editing Done has a pill of its own")
  func editingDoneHasItsOwnPill() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let editingDone = try #require(harness.viewController.editingDoneBarButtonItem)
      #expect(!editingDone.sharesBackground)
    }
  }

  /// Pinned, so on iPhone Duo's vertical bar it sits at the top of the column rather than among
  /// the other items, and never falls into the overflow.
  @Test("typing pins the editing Done, and ending gives the pin back", arguments: [false, true])
  func editingDoneIsPinned(isNewChecklist: Bool) throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems, isNewChecklist: isNewChecklist) { harness in
      let controller = harness.viewController
      harness.header.nameTextField.becomeFirstResponder()

      #expect(controller.pinnedTrailingItem === controller.editingDoneBarButtonItem)
      let rest = controller.navigationItem.rightBarButtonItems ?? []
      #expect(!rest.contains { $0 === controller.editingDoneBarButtonItem })

      controller.view.endEditing(true)
      settle()
      // The create sheet's own Done takes the pin back; an existing checklist pins nothing.
      let expected = isNewChecklist ? controller.primaryBarButtonItem : nil
      #expect(controller.pinnedTrailingItem === expected)
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
      #expect(bar(harness.viewController) == Self.pushedIdle)
    }
  }

  /// The button VoiceOver was on goes with the edit, so VoiceOver moves to what takes its place at
  /// the outer edge: the menu, or on the create sheet, the sheet's own Done.
  @Test("tapping the editing Done moves VoiceOver to what takes its place", arguments: [false, true])
  func editingDoneMovesVoiceOverToItsReplacement(isNewChecklist: Bool) throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems, isNewChecklist: isNewChecklist) { harness in
      let controller = harness.viewController
      let replacement = try #require(isNewChecklist ? controller.primaryBarButtonItem : controller.moreBarButtonItem)
      var focused: [NSObject?] = []
      controller.barSwapFocusDelay = nil
      controller.accessibilityFeedback = { focus, _ in focused.append(focus) }
      harness.header.nameTextField.becomeFirstResponder()

      controller.editingDoneTapped()

      #expect(focused.count == 1)
      #expect(focused.first.flatMap(\.self) === replacement)
    }
  }

  /// Return hands focus from one row to a new one below it; the editing Done must not blink out and
  /// back on the way.
  @Test("Return on an item's name keeps the editing Done throughout the hand-off")
  func returnHandOffKeepsTheEditingDone() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let controller = harness.viewController
      let row = try firstRow(harness)
      row.itemContentView.startEditing()

      controller.itemContentViewDidReturnOnNameField(row.itemContentView)
      var barsSeen: [[String]] = []
      for _ in 0 ..< 40 {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
        barsSeen.append(bar(controller))
      }

      #expect(harness.checklist.items.count == 4)
      let alwaysTyping = barsSeen.allSatisfy { $0 == Self.pushedTyping }
      #expect(alwaysTyping)
    }
  }

  @Test("Reorder Items mode entered mid-edit leaves with the idle bar, not the editing Done")
  func reorderMidEditRestoresTheIdleBar() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let controller = harness.viewController
      harness.header.nameTextField.becomeFirstResponder()

      controller.enterReorderMode()
      settle()
      #expect(bar(controller) == ["checklist.reorderDone"])

      controller.setEditing(false, animated: false)
      #expect(bar(controller) == Self.pushedIdle)
    }
  }
}
