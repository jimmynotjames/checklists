//
//  ChecklistEditingDoneTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import Testing
import UIKit

/// Covers the navigation bar's editing Done: added at the outer edge while a field on an existing
/// checklist is being typed into, as Notes does it. The create sheet keeps its own Done instead.
///
/// `.serialized` for the reason `ChecklistMenuActionTests` gives: the harness controller registers a
/// `RemoteChangeObserver`.
@Suite("Checklist editing Done", .serialized)
struct ChecklistEditingDoneTests {
  private static let threeItems: [(name: String, isChecked: Bool)] = [("Milk", false), ("Bread", true), ("Eggs", false)]

  /// The trailing bar items, outer edge first: the pinned item, if any, then the rest. `primary` is
  /// Reset on an existing checklist and Done on the create sheet.
  private func bar(_ controller: ChecklistViewController) -> [ChecklistBar.Item] {
    let pinned = controller.bar.pinnedItem.map { [$0] } ?? []
    return pinned + controller.bar.trailingItems
  }

  private static let pushedIdle: [ChecklistBar.Item] = [.more, .primary]
  private static let pushedTyping: [ChecklistBar.Item] = [.editingDone, .more, .primary]
  private static let createIdle: [ChecklistBar.Item] = [.primary, .more]
  private static let createTyping: [ChecklistBar.Item] = [.primary, .more]

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

  @Test("on the create sheet, typing keeps the sheet's own Done at the outer edge")
  func createSheetKeepsItsDoneWhileTyping() throws {
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

  /// Pinned, so on iPhone Duo's vertical bar it sits at the top of the column rather than among
  /// the other items, and never falls into the overflow.
  @Test("typing pins the editing Done, and ending gives the pin back")
  func editingDoneIsPinned() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems) { harness in
      let controller = harness.viewController
      harness.header.nameTextField.becomeFirstResponder()

      #expect(controller.bar.pinnedItem == .editingDone)
      #expect(!controller.bar.trailingItems.contains(.editingDone))

      controller.view.endEditing(true)
      settle()
      #expect(controller.bar.pinnedItem == nil)
    }
  }

  /// Done stays in the bar while typing, so one tap must keep what was typed before the sheet goes:
  /// the source screen of a move names the new checklist in its toast as soon as the sheet closes.
  @Test("the create sheet's Done tapped mid-typing keeps what was typed before closing")
  func createSheetDoneCommitsBeforeClosing() throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems, isNewChecklist: true) { harness in
      let nameField = harness.header.nameTextField
      nameField.becomeFirstResponder()
      nameField.text = "Pantry"
      var nameWhenClosing: String?
      harness.viewController.onRequestDismiss = { nameWhenClosing = harness.checklist.name }

      harness.viewController.perform(.primary)

      #expect(nameWhenClosing == "Pantry")
      #expect(!nameField.isFirstResponder)
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
  /// the outer edge, the menu. On the create sheet only Esc ends typing this way, and the bar does
  /// not change, so VoiceOver stays where it was.
  @Test("ending typing moves VoiceOver off the vanishing editing Done, and leaves it alone on the create sheet", arguments: [false, true])
  func endingTypingMovesVoiceOverOnlyWhenTheBarSwaps(isNewChecklist: Bool) throws {
    try ChecklistScreenHarness.withController(items: Self.threeItems, isNewChecklist: isNewChecklist) { harness in
      let controller = harness.viewController
      controller.barSwapFocusDelay = nil
      harness.header.nameTextField.becomeFirstResponder()

      controller.editingDoneTapped()

      #expect(controller.bar.focusRequest == (isNewChecklist ? nil : ChecklistBar.FocusRequest(item: .more, generation: 1)))
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
      var barsSeen: [[ChecklistBar.Item]] = []
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
      #expect(bar(controller) == [.reorderDone])

      controller.setEditing(false, animated: false)
      #expect(bar(controller) == Self.pushedIdle)
    }
  }
}
