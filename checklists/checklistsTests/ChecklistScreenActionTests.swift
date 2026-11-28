//
//  ChecklistScreenActionTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing
import UIKit

/// Covers the checklist screen's own actions — reset, the checkbox, item duplication and the
/// remote-change handler. The overflow menu's actions are in `ChecklistMenuActionTests`.
/// `.serialized` — same `RemoteChangeObserver` reason as `ChecklistMenuActionTests`.
@Suite("Checklist screen actions", .serialized)
struct ChecklistScreenActionTests {
  // MARK: - Reset

  @Test("reset unchecks every item and records the update")
  func resetUnchecksEveryItem() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", true), ("Bread", true)],
    ) { harness in
      harness.viewController.resetButtonTapped()

      #expect(harness.checklist.items.allSatisfy { $0.status == .unchecked })
      #expect(harness.checklist.lastUpdated != nil)
      #expect(harness.analytics.count(of: AnalyticsEvent.checklistReset) == 1)

      let verification = ModelContext(harness.modelContext.container)
      let saved = try verification.fetch(FetchDescriptor<Item>())
      #expect(saved.allSatisfy { $0.status == .unchecked }, "The reset is saved, not just staged.")
    }
  }

  /// `lastUpdated` records an item's checked state changing. A reset on a list where nothing was
  /// ticked changes none, so dating it would claim an update that never happened.
  @Test("resetting an untouched checklist does not date it")
  func resetOnUntouchedChecklistDoesNotDateIt() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", false), ("Bread", false)],
    ) { harness in
      harness.viewController.resetButtonTapped()

      #expect(harness.checklist.lastUpdated == nil)
      #expect(
        harness.analytics.count(of: AnalyticsEvent.checklistReset) == 1,
        "The action still happened, even though it changed nothing.",
      )
    }
  }

  /// Reset does not clear `lastCompleted`: it records a finished run, not a claim about the list's
  /// current state.
  @Test("reset leaves an earlier completion recorded")
  func resetKeepsTheCompletionStamp() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      let itemContentView = ItemContentView()
      itemContentView.item = harness.checklist.items[0]
      harness.viewController.itemContentViewCheckboxButtonTapped(itemContentView)
      let completedAt = harness.checklist.lastCompleted
      #expect(completedAt != nil, "Checking the only item completes the list.")

      harness.viewController.resetButtonTapped()

      #expect(harness.checklist.lastCompleted == completedAt)
    }
  }

  // MARK: - The checkbox

  @Test("checking an item saves its status and dates the checklist")
  func checkingAnItemSavesAndDates() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", false), ("Bread", false)],
    ) { harness in
      let itemContentView = ItemContentView()
      itemContentView.item = harness.checklist.items[0]

      harness.viewController.itemContentViewCheckboxButtonTapped(itemContentView)

      #expect(harness.checklist.items[0].status == .checked)
      #expect(harness.checklist.lastUpdated != nil)
      #expect(harness.checklist.lastCompleted == nil, "One of two items is not a completed list.")

      let verification = ModelContext(harness.modelContext.container)
      let saved = try verification.fetch(FetchDescriptor<Item>()).first { $0.name == "Milk" }
      #expect(saved?.status == .checked, "The tick is saved, not just staged.")
    }
  }

  @Test("checking the last outstanding item completes the checklist")
  func checkingTheLastItemCompletesTheChecklist() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", true), ("Bread", false)],
    ) { harness in
      let itemContentView = ItemContentView()
      itemContentView.item = try #require(harness.checklist.items.first { $0.name == "Bread" })

      harness.viewController.itemContentViewCheckboxButtonTapped(itemContentView)

      #expect(harness.checklist.isComplete)
      #expect(harness.checklist.lastCompleted != nil)
    }
  }

  // MARK: - Duplicating an item

  /// The failure path is pinned in `InsertRollbackTests`.
  @Test("duplicating an item places the copy directly beneath it")
  func duplicatingAnItemPlacesTheCopyBeneathIt() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", true), ("Bread", false)],
    ) { harness in
      harness.viewController.duplicateItem(at: 0)

      #expect(harness.itemNames == ["Milk", "Milk", "Bread"])
      #expect(
        harness.checklist.items[1].status == .unchecked,
        "A copy has not been done yet, whatever the original's state.",
      )
      let persisted = try harness.persistedItemNames()
      #expect(persisted == ["Milk", "Milk", "Bread"], "The copy is saved, not just staged.")
      #expect(harness.analytics.count(of: AnalyticsEvent.checklistItemDuplicated) == 1)
    }
  }

  // MARK: - Remote changes

  /// Deleted on another device while this screen was open, for the reason `handleRemoteChange`
  /// gives.
  @Test("a checklist deleted elsewhere dismisses the screen")
  func remoteDeletionDismissesTheScreen() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      var dismissed = false
      harness.viewController.onRequestDismiss = { dismissed = true }

      harness.modelContext.delete(harness.checklist)
      try harness.modelContext.save()
      harness.viewController.handleRemoteChange()

      #expect(dismissed)
    }
  }

  /// Sample dedupe deletes one of two records sharing an `id`. The surviving twin must not keep the
  /// screen open on the deleted one.
  @Test("a checklist deduped away dismisses the screen even though its twin survives")
  func dedupedTwinDismissesTheScreen() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      var dismissed = false
      harness.viewController.onRequestDismiss = { dismissed = true }
      harness.modelContext.insert(Checklist(id: harness.checklist.id, name: "Twin"))

      harness.modelContext.delete(harness.checklist)
      try harness.modelContext.save()
      harness.viewController.handleRemoteChange()

      #expect(dismissed)
    }
  }

  /// The host shows a toast from this, so it must fire for another device's delete only, and once.
  @Test("another device's delete is reported once, however many changes arrive")
  func remoteDeletionIsReportedOnce() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      var reports = 0
      harness.viewController.onRequestDismiss = {}
      harness.viewController.onRemoteDeletion = { reports += 1 }

      harness.modelContext.delete(harness.checklist)
      try harness.modelContext.save()
      harness.viewController.handleRemoteChange()
      harness.viewController.handleRemoteChange()

      #expect(reports == 1)
    }
  }

  @Test("a checklist deduped away is not reported as deleted elsewhere")
  func dedupedTwinIsNotReported() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      var reported = false
      harness.viewController.onRequestDismiss = {}
      harness.viewController.onRemoteDeletion = { reported = true }
      harness.modelContext.insert(Checklist(id: harness.checklist.id, name: "Twin"))

      harness.modelContext.delete(harness.checklist)
      try harness.modelContext.save()
      harness.viewController.handleRemoteChange()

      #expect(!reported)
    }
  }

  /// The screen's own Delete Checklist comes back as a store change while the screen leaves.
  @Test("this screen's own delete is not reported as deleted elsewhere")
  func ownDeleteIsNotReported() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      var reported = false
      harness.viewController.onRequestDismiss = {}
      harness.viewController.onRemoteDeletion = { reported = true }

      harness.viewController.deleteChecklist()
      harness.viewController.handleRemoteChange()

      #expect(!reported)
    }
  }

  @Test("a still-present checklist is not dismissed")
  func remoteChangeToALivingChecklistDoesNotDismiss() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      var dismissed = false
      harness.viewController.onRequestDismiss = { dismissed = true }

      harness.viewController.handleRemoteChange()

      #expect(!dismissed)
    }
  }

  /// A name merged from another device reaches the header, which reads from the model only on a
  /// reload it is told about.
  @Test("a merged name is pushed into the header field")
  func mergedNameReachesTheHeader() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      harness.checklist.name = "Weekly shop"

      harness.viewController.handleRemoteChange()

      #expect(harness.header.nameTextField.text == "Weekly shop")
    }
  }

  /// A merge must never yank the table out from under an active edit. The merged values are
  /// already in the model, so the cost of waiting is nothing; the cost of not waiting is the user's
  /// half-typed text disappearing.
  @Test("a merge arriving mid-edit leaves the field alone")
  func mergeDuringAnEditLeavesTheFieldAlone() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      harness.header.nameTextField.text = "half-typed"
      #expect(harness.header.nameTextField.becomeFirstResponder(), "The guard under test needs a real first responder.")
      harness.checklist.name = "Merged from elsewhere"

      harness.viewController.handleRemoteChange()

      #expect(harness.header.nameTextField.text == "half-typed")
    }
  }

  /// A merge must never restamp `lastCompleted`: the device that completed the list already
  /// stamped it and that field syncs, so a local restamp would win last-writer-wins and replace the
  /// true completion moment with the merge time.
  @Test("a merge arriving at 100% does not stamp the completion")
  func mergeAtFullCompletionDoesNotStamp() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", true)]) { harness in
      #expect(harness.checklist.isComplete)
      #expect(harness.checklist.lastCompleted == nil, "Seeded as checked, never completed here.")

      harness.viewController.handleRemoteChange()

      #expect(harness.checklist.lastCompleted == nil)
    }
  }

  /// A full reload hands the visible cells back out in reverse, so a long-press lift in progress
  /// keeps drawing a cell that now shows another row, and that row appears on top of the pressed
  /// one. A merge that leaves the row count alone must keep every cell where it is.
  @Test("a remote change keeps every visible cell on its row")
  func remoteChangeKeepsCellsOnTheirRows() throws {
    try ChecklistScreenHarness.withController(
      items: [("One", false), ("Two", false), ("Three", false), ("Four", false), ("Five", false)],
    ) { harness in
      let before = try cellIdentities(in: harness.table, rows: 5)

      harness.viewController.handleRemoteChange()
      harness.table.layoutIfNeeded()

      #expect(try cellIdentities(in: harness.table, rows: 5) == before)
    }
  }

  @Test("a merged item name reaches its row")
  func mergedItemNameReachesItsRow() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false), ("Bread", false)]) { harness in
      harness.checklist.items[1].name = "Sourdough"

      harness.viewController.handleRemoteChange()
      harness.table.layoutIfNeeded()

      let cell = try #require(harness.table.cellForRow(at: IndexPath(row: 1, section: 0)) as? ItemTableViewCell)
      let nameField = try #require(findTextView(identifier: "itemNameTextView", in: cell.itemContentView))
      #expect(nameField.text == "Sourdough")
    }
  }

  /// A merge that changes nothing, such as CloudKit echoing this screen's own save, must leave every
  /// row alone, so a row under a long-press is never rewritten for nothing. `cellForRowAt` issues
  /// new VoiceOver action objects, so the same ones afterwards mean the row was not rebuilt.
  @Test("a merge touches only the rows it changed")
  func mergeTouchesOnlyChangedRows() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", false), ("Bread", false), ("Eggs", false)],
    ) { harness in
      let before = try (0 ..< 3).map { try firstAccessibilityAction(in: harness.table, row: $0) }

      harness.viewController.handleRemoteChange()
      harness.table.layoutIfNeeded()

      let afterEcho = try (0 ..< 3).map { try firstAccessibilityAction(in: harness.table, row: $0) }
      #expect(zip(before, afterEcho).allSatisfy { $0 === $1 }, "Nothing changed, so no row is rebuilt.")

      harness.checklist.items[1].status = .checked
      harness.viewController.handleRemoteChange()
      harness.table.layoutIfNeeded()

      let afterTick = try (0 ..< 3).map { try firstAccessibilityAction(in: harness.table, row: $0) }
      #expect(afterTick[0] === before[0])
      #expect(afterTick[1] !== before[1], "The ticked row is refreshed.")
      #expect(afterTick[2] === before[2])
    }
  }

  /// The same count with the items in a new order: each row must show the item now at its place.
  @Test("a reorder made elsewhere reaches the rows")
  func reorderMadeElsewhereReachesTheRows() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false), ("Bread", false)]) { harness in
      let items = harness.checklist.items
      (items[0].sortKey, items[1].sortKey) = (items[1].sortKey, items[0].sortKey)

      harness.viewController.handleRemoteChange()
      harness.table.layoutIfNeeded()

      let shown = try (0 ..< 2).map { row in
        let cell = try #require(harness.table.cellForRow(at: IndexPath(row: row, section: 0)) as? ItemTableViewCell)
        return try #require(findTextView(identifier: "itemNameTextView", in: cell.itemContentView)).text
      }
      #expect(shown == ["Bread", "Milk"])
    }
  }

  @Test("merged notes grow their row")
  func mergedNotesGrowTheirRow() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false), ("Bread", false)]) { harness in
      let heightBefore = harness.table.rectForRow(at: IndexPath(row: 0, section: 0)).height
      harness.checklist.items[0].notes = "Semi-skimmed, two litres, from the shop on the corner."

      harness.viewController.handleRemoteChange()
      harness.table.layoutIfNeeded()

      #expect(harness.table.rectForRow(at: IndexPath(row: 0, section: 0)).height > heightBefore)
    }
  }

  @Test("an item added elsewhere appears")
  func itemAddedElsewhereAppears() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      let added = Item()
      added.name = "Eggs"
      added.sortKey = 2
      harness.modelContext.insert(added)
      added.checklist = harness.checklist
      try harness.modelContext.save()

      harness.viewController.handleRemoteChange()

      #expect(harness.table.numberOfRows(inSection: 0) == 2)
    }
  }

  // MARK: - Helpers

  private func cellIdentities(in table: UITableView, rows: Int) throws -> [ObjectIdentifier] {
    try (0 ..< rows).map { row in
      try ObjectIdentifier(#require(table.cellForRow(at: IndexPath(row: row, section: 0))))
    }
  }

  private func firstAccessibilityAction(in table: UITableView, row: Int) throws -> UIAccessibilityCustomAction {
    let cell = try #require(table.cellForRow(at: IndexPath(row: row, section: 0)) as? ItemTableViewCell)
    let nameField = try #require(findTextView(identifier: "itemNameTextView", in: cell.itemContentView))
    return try #require(nameField.accessibilityCustomActions?.first)
  }

  /// The item fields are private; each carries its own `accessibilityIdentifier`.
  private func findTextView(identifier: String, in view: UIView) -> UITextView? {
    if let textView = view as? UITextView, textView.accessibilityIdentifier == identifier {
      return textView
    }
    for subview in view.subviews {
      if let found = findTextView(identifier: identifier, in: subview) {
        return found
      }
    }
    return nil
  }
}
