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
      items: [("Milk", true), ("Bread", true)]
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
      items: [("Milk", false), ("Bread", false)]
    ) { harness in
      harness.viewController.resetButtonTapped()

      #expect(harness.checklist.lastUpdated == nil)
      #expect(
        harness.analytics.count(of: AnalyticsEvent.checklistReset) == 1,
        "The action still happened, even though it changed nothing."
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
      items: [("Milk", false), ("Bread", false)]
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
      items: [("Milk", true), ("Bread", false)]
    ) { harness in
      let itemContentView = ItemContentView()
      itemContentView.item = try #require(harness.checklist.items.first { $0.name == "Bread" })

      harness.viewController.itemContentViewCheckboxButtonTapped(itemContentView)

      #expect(harness.checklist.isComplete)
      #expect(harness.checklist.lastCompleted != nil)
    }
  }

  // MARK: - Duplicating an item

  /// There is deliberately no failure-path test here. There is no seam to fail the save, and
  /// `ItemDuplication` goes through `insert(item:at:in:)`, which stages the copy without rolling it
  /// back — so a forced failure would leave a half-inserted item with the table not updated. That
  /// is issue #219, not something to pin here.
  @Test("duplicating an item places the copy directly beneath it")
  func duplicatingAnItemPlacesTheCopyBeneathIt() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", true), ("Bread", false)]
    ) { harness in
      harness.viewController.duplicateItem(at: 0)

      #expect(harness.itemNames == ["Milk", "Milk", "Bread"])
      #expect(
        harness.checklist.items[1].status == .unchecked,
        "A copy has not been done yet, whatever the original's state."
      )
      let persisted = try harness.persistedItemNames()
      #expect(persisted == ["Milk", "Milk", "Bread"], "The copy is saved, not just staged.")
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
}
