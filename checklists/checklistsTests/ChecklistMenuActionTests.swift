//
//  ChecklistMenuActionTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing
import UIKit

/// Covers the checklist screen's overflow-menu actions.
///
/// The menu entries themselves are `UIAction` handlers, which cannot be fired from a test, so each
/// action is invoked directly. What that still covers is everything between the tap and the store.
/// `.serialized` because the controller this builds registers a `RemoteChangeObserver`, which does
/// not filter by store: a burst posted by `RemoteChangeObserverTests` would otherwise reach a live
/// harness controller mid-test and, in the deletion cases, dismiss the screen out from under it.
/// `scripts/test-unit.sh` already passes `-parallel-testing-enabled NO`, but that is a property of
/// the runner — this states the requirement where it applies, so running from Xcode is safe too.
@Suite("Checklist overflow menu actions", .serialized)
struct ChecklistMenuActionTests {
  // MARK: - Delete

  @Test("deleting removes the checklist and its items")
  func deleteRemovesTheChecklistAndItsItems() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", false), ("Bread", false)]
    ) { harness in
      harness.viewController.deleteChecklist()

      let verification = ModelContext(harness.modelContext.container)
      #expect(try verification.fetchChecklistsSorted().isEmpty)
      let orphanedItems = try verification.fetch(FetchDescriptor<Item>())
      #expect(orphanedItems.isEmpty, "The cascade rule takes the items with the checklist.")
      #expect(harness.analytics.count(of: AnalyticsEvent.checklistDeleted) == 1)
    }
  }

  /// The order is load-bearing, for the reason `deleteChecklist` gives: the screen leaves before
  /// the record does.
  @Test("the screen is dismissed before the checklist is deleted")
  func dismissalPrecedesDeletion() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      var wasDeletedAtDismissal: Bool?
      // Captures the checklist, not the harness: the harness holds the controller, which holds
      // this closure, and that cycle would outlive the `defer` that is meant to release it.
      let checklist = harness.checklist
      harness.viewController.onRequestDismiss = {
        wasDeletedAtDismissal = checklist.isDeleted
      }

      harness.viewController.deleteChecklist()

      #expect(wasDeletedAtDismissal == false, "Dismissal must happen while the record is still valid.")
    }
  }

  // MARK: - Duplicate

  @Test("duplicating adds a copy and opens it")
  func duplicatingAddsACopyAndOpensIt() throws {
    try ChecklistScreenHarness.withController(
      name: "Packing",
      items: [("Passport", true), ("Charger", false)]
    ) { harness in
      var openedId: String?
      harness.viewController.onRequestOpenDuplicate = { openedId = $0 }

      harness.viewController.duplicateChecklist()

      let verification = ModelContext(harness.modelContext.container)
      let checklists = try verification.fetchChecklistsSorted()
      #expect(checklists.map(\.name) == ["Packing", "Packing copy"])
      let copy = try #require(checklists.last)
      #expect(copy.items.map(\.name) == ["Passport", "Charger"], "Order carries over.")
      #expect(
        copy.items.allSatisfy { $0.status == .unchecked },
        "A duplicate has never been run, so nothing is ticked."
      )
      #expect(openedId == copy.id)
      #expect(harness.analytics.count(of: AnalyticsEvent.checklistDuplicated) == 1)
    }
  }

  /// The copy carries what is on screen, not the last value that happened to be saved.
  @Test("an uncommitted name is committed into the source before copying")
  func uncommittedNameIsCommittedBeforeCopying() throws {
    try ChecklistScreenHarness.withController(
      name: "Packing",
      items: [("Passport", false)]
    ) { harness in
      harness.header.nameTextField.text = "Trip"
      harness.header.nameTextField.becomeFirstResponder()

      harness.viewController.duplicateChecklist()

      #expect(harness.checklist.name == "Trip")
      let verification = ModelContext(harness.modelContext.container)
      let names = try verification.fetchChecklistsSorted().map(\.name)
      #expect(names == ["Trip", "Trip copy"])
    }
  }

  /// The duplication source is what separates "used the menu" from "used the swipe" on the
  /// dashboards, so the wrong value is worse than none.
  @Test("the duplication is reported as coming from the menu")
  func duplicationIsReportedAsFromTheMenu() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      harness.viewController.duplicateChecklist()

      let source = harness.analytics.properties(forFirst: AnalyticsEvent.checklistDuplicated)?[
        AnalyticsProperty.source
      ]
      #expect(source == ChecklistDuplicationSource.menu.rawValue)
    }
  }
}
