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
/// The controller this builds registers a `RemoteChangeObserver` on `.default`, which does not filter
/// by store: a remote-change or dedupe post from another suite could reach a live harness controller
/// mid-test and, in the deletion cases, dismiss the screen out from under it. What keeps other suites
/// from running alongside is the runner's `-parallel-testing-enabled NO` (`scripts/test-unit.sh`);
/// `.serialized` only orders this suite's own tests.
@Suite("Checklist overflow menu actions", .serialized)
struct ChecklistMenuActionTests {
  // MARK: - Delete

  @Test("deleting removes the checklist and its items")
  func deleteRemovesTheChecklistAndItsItems() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", false), ("Bread", false)],
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

  // MARK: - Delete Checked Items

  @Test("deleting checked items removes the ticked rows and keeps the rest")
  func deleteCheckedItemsKeepsTheUnchecked() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", true), ("Bread", false), ("Eggs", true), ("Tea", false)],
    ) { harness in
      harness.viewController.deleteCheckedItems()

      #expect(harness.itemNames == ["Bread", "Tea"])
      let persisted = try harness.persistedItemNames()
      #expect(persisted == ["Bread", "Tea"], "The deletion is saved, not just staged.")
      #expect(harness.table.numberOfRows(inSection: 0) == 2)
      let count = harness.analytics.properties(forFirst: AnalyticsEvent.checklistCheckedItemsDeleted)?[
        AnalyticsProperty.itemsCount,
      ]
      #expect(count == "2")
    }
  }

  /// Ticking every item and deleting them leaves an empty list, and an empty list is never complete
  /// (persistence-design.md §The two history stamps), so this must not stamp a completion.
  @Test("deleting every item leaves an empty, uncompleted list")
  func deleteCheckedItemsCanEmptyTheList() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", true), ("Bread", true)],
    ) { harness in
      harness.viewController.deleteCheckedItems()

      #expect(harness.itemNames.isEmpty)
      #expect(harness.checklist.lastCompleted == nil)
    }
  }

  @Test("with nothing checked, nothing is deleted or reported")
  func deleteCheckedItemsWithNothingChecked() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", false), ("Bread", false)],
    ) { harness in
      harness.viewController.deleteCheckedItems()

      #expect(harness.itemNames == ["Milk", "Bread"])
      #expect(harness.analytics.count(of: AnalyticsEvent.checklistCheckedItemsDeleted) == 0)
    }
  }

  // MARK: - Copy and Move Checked Items

  /// The picker is the host's to present; all the controller owes it is which list, and which mode.
  @Test("the copy and move entries hand the host this checklist and their mode")
  func transferEntriesHandOverTheirMode() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", true)]) { harness in
      var requests: [CheckedItemsTransferMode] = []
      var requestedIds: Set<String> = []
      harness.viewController.onRequestTransferCheckedItems = { id, mode in
        requestedIds.insert(id)
        requests.append(mode)
      }

      harness.viewController.transferCheckedItems(.copy)
      harness.viewController.transferCheckedItems(.move)

      #expect(requests == [.copy, .move])
      #expect(requestedIds == [harness.checklist.id])
    }
  }

  // MARK: - Export as PDF

  @Test("an uncommitted name is committed before exporting")
  func uncommittedNameIsCommittedBeforeExporting() throws {
    try ChecklistScreenHarness.withController(name: "Packing", items: [("Passport", false)]) { harness in
      harness.header.nameTextField.text = "Trip"
      harness.header.nameTextField.becomeFirstResponder()

      harness.viewController.exportPDF()

      #expect(harness.checklist.name == "Trip")
      // The harness window has no scene to present the share sheet in, so nothing deletes the file.
      try? FileManager.default.removeItem(at: PDFExportFile.rootDirectory)
    }
  }

  @Test("the exported file is named for the checklist and today's date")
  func exportedFileIsNamedForTheChecklistAndToday() throws {
    try ChecklistScreenHarness.withController(name: "Packing", items: [("Passport", false)]) { harness in
      let snapshot = ChecklistPDFSnapshot.make(from: harness.checklist, isRightToLeft: false)

      let url = try harness.viewController.makePDFExportFile(for: snapshot)
      defer { PDFExportFile.remove(url) }

      #expect(url.lastPathComponent == PDFFileName.make(title: "Packing", date: .now, timeZone: .current))
      #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }
  }

  @Test("Export as PDF… has its own section, between copy and move and the deletes")
  func exportEntryHasItsOwnSection() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      let sections = harness.viewController.makeMoreMenu().children.compactMap { $0 as? UIMenu }

      #expect(sections.count == 4)
      let exportSection = try #require(sections.dropFirst(2).first)
      let entry = try #require(exportSection.children.first as? UIAction)
      #expect(exportSection.children.count == 1)
      #expect(entry.accessibilityIdentifier == "checklist.menu.exportPDF")
    }
  }

  @Test("the create sheet's menu has no export entry")
  func createSheetHasNoExportEntry() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)], isNewChecklist: true) { harness in
      let identifiers = harness.viewController.makeMoreMenu().children
        .compactMap { $0 as? UIMenu }
        .flatMap(\.children)
        .compactMap { ($0 as? UIAction)?.accessibilityIdentifier }

      #expect(!identifiers.contains("checklist.menu.exportPDF"))
      #expect(identifiers.contains("checklist.menu.reorderItems"))
    }
  }

  // MARK: - Duplicate

  @Test("duplicating adds a copy and opens it")
  func duplicatingAddsACopyAndOpensIt() throws {
    try ChecklistScreenHarness.withController(
      name: "Packing",
      items: [("Passport", true), ("Charger", false)],
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
        "A duplicate has never been run, so nothing is ticked.",
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
      items: [("Passport", false)],
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
        AnalyticsProperty.source,
      ]
      #expect(source == ChecklistDuplicationSource.menu.rawValue)
    }
  }
}
