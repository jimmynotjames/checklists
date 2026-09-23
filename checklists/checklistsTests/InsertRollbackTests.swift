//
//  InsertRollbackTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing

/// Covers what the insert paths leave behind when their save fails, and who hears about it.
///
/// A real SwiftData save only fails on a full or damaged disk, so the failure is injected through
/// `insertAndSave`'s `save` closure. Siblings are seeded with keys too close to split, so every
/// insert here renormalizes them first — the sort-key writes a rollback must also undo.
@Suite("Rolling back an insert whose save failed")
struct InsertRollbackTests {
  private struct SaveFailure: Error {}

  /// Below `SortKeyReorder.epsilon` once halved, so inserting at the top renormalizes.
  private static let crowdedKeys = [1e-7, 2e-7]

  @Test("a failed checklist insert leaves no checklist and the siblings' keys as they were")
  func failedChecklistInsertLeavesNothing() throws {
    let context = try TestModelContainer.makeContext()
    let siblings = Self.crowdedKeys.map { key in
      let checklist = Checklist(name: "existing")
      checklist.sortKey = key
      context.insert(checklist)
      return checklist
    }
    try context.save()

    #expect(throws: SaveFailure.self) {
      try context.insertAndSave(Checklist(name: "new"), at: 0, among: siblings) { throw SaveFailure() }
    }

    #expect(try context.fetch(FetchDescriptor<Checklist>()).map(\.name) == ["existing", "existing"])
    #expect(siblings.map(\.sortKey) == Self.crowdedKeys, "Renormalized keys must be put back too.")

    // Whatever is still pending must not include the checklist, or autosave could write it later.
    try context.save()
    let verification = ModelContext(context.container)
    #expect(try verification.fetchCount(FetchDescriptor<Checklist>()) == 2)
  }

  @Test("a failed item insert leaves the checklist's items as they were")
  func failedItemInsertLeavesNothing() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = Checklist()
    context.insert(checklist)
    for (offset, key) in Self.crowdedKeys.enumerated() {
      let item = Item(name: "item \(offset)", notes: "", sortKey: key)
      context.insert(item)
      item.checklist = checklist
    }
    try context.save()

    #expect(throws: SaveFailure.self) {
      try context.insertAndSave(Item(name: "new", notes: "", sortKey: 0), at: 0, in: checklist) {
        throw SaveFailure()
      }
    }

    // What the detail screen's data source counts; one extra here is the table/data-source mismatch.
    #expect(checklist.items.map(\.name) == ["item 0", "item 1"])
    #expect(checklist.items.map(\.sortKey) == Self.crowdedKeys, "Renormalized keys must be put back too.")

    try context.save()
    let verification = ModelContext(context.container)
    #expect(try verification.fetch(FetchDescriptor<Item>()).map(\.name).sorted() == ["item 0", "item 1"])
  }

  @Test("a successful insert is saved")
  func successfulInsertIsSaved() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = Checklist()
    context.insert(checklist)
    try context.save()

    try context.insert(item: Item(name: "new", notes: "", sortKey: 0), at: 0, in: checklist)

    let verification = ModelContext(context.container)
    #expect(try verification.fetch(FetchDescriptor<Item>()).map(\.name) == ["new"])
  }
}

@Suite("Telling the person a save failed")
struct SaveFailureNotifierTests {
  @Test("a failed edit notifies", arguments: [
    PersistenceOperation.checklistEdit, .itemEdit, .itemUpdate, .reorder, .delete,
  ])
  func failedEditNotifies(operation: PersistenceOperation) {
    var notified = 0
    SaveFailureNotifier.saveFailed(during: operation) { notified += 1 }
    #expect(notified == 1)
  }

  /// Startup's saves have the failure screen, or are dropped on purpose.
  @Test("a failed startup save does not notify", arguments: [
    PersistenceOperation.legacyImport, .sampleSeed, .dedupe,
  ])
  func failedStartupSaveDoesNotNotify(operation: PersistenceOperation) {
    var notified = 0
    SaveFailureNotifier.saveFailed(during: operation) { notified += 1 }
    #expect(notified == 0)
  }
}
