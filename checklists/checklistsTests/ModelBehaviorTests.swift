//
//  ModelBehaviorTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing
import UniformTypeIdentifiers

/// Covers the ordering/mutation methods that replace Realm's `List` mutators (`Reordering.swift`),
/// plus `Item.toggleStatus()`, `Checklist.uncheckAllItems()`, and the `dragItems()` `NSItemProvider`
/// round trip on both model types.
///
/// Reorder tests assert the resulting **order** via `fetchChecklistsSorted()` / `checklist.items`
/// rather than specific `sortKey` values — the values are an implementation detail of
/// `SortKeyReorder`, already covered directly by `SortKeyReorderTests`.
@Suite("Model ordering, status, and drag payloads")
struct ModelBehaviorTests {
  // MARK: - Checklist reordering

  @Test("moving a checklist to the end reorders the sorted fetch")
  func moveChecklistReordersByKey() throws {
    let context = try TestModelContainer.makeContext()
    let checklistA = Checklist(name: "A", sortKey: 1.0)
    let checklistB = Checklist(name: "B", sortKey: 2.0)
    let checklistC = Checklist(name: "C", sortKey: 3.0)
    for checklist in [checklistA, checklistB, checklistC] {
      context.insert(checklist)
    }
    try context.saveChanges(operation: .checklistEdit)

    // Move A to the end: [A, B, C] -> [B, C, A].
    try context.move(checklist: checklistA, among: [checklistA, checklistB, checklistC], to: 2)

    #expect(try context.fetchChecklistsSorted().map(\.name) == ["B", "C", "A"])
  }

  @Test("inserting at index 0 puts the new checklist first")
  func insertChecklistAtTop() throws {
    let context = try TestModelContainer.makeContext()
    let existingOne = Checklist(name: "Existing One", sortKey: 1.0)
    let existingTwo = Checklist(name: "Existing Two", sortKey: 2.0)
    context.insert(existingOne)
    context.insert(existingTwo)
    try context.saveChanges(operation: .checklistEdit)

    let newChecklist = Checklist(name: "New")
    try context.insert(checklist: newChecklist, at: 0, among: [existingOne, existingTwo])

    #expect(try context.fetchChecklistsSorted().map(\.name) == ["New", "Existing One", "Existing Two"])
  }

  // MARK: - Item reordering

  @Test("moving an item to the end reorders its parent's items")
  func moveItemReordersByKey() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = Checklist(name: "Test", sortKey: 1.0)
    context.insert(checklist)

    let itemOne = Item(name: "one", sortKey: 1.0)
    let itemTwo = Item(name: "two", sortKey: 2.0)
    let itemThree = Item(name: "three", sortKey: 3.0)
    for item in [itemOne, itemTwo, itemThree] {
      context.insert(item)
      item.checklist = checklist
    }
    try context.saveChanges(operation: .itemEdit)

    // Move "one" to the end: [one, two, three] -> [two, three, one].
    try context.move(item: itemOne, among: [itemOne, itemTwo, itemThree], to: 2)

    #expect(checklist.items.map(\.name) == ["two", "three", "one"])
  }

  // MARK: - Status mutation

  @Test("toggleStatus() flips unchecked to checked and back")
  func toggleStatus() throws {
    let context = try TestModelContainer.makeContext()
    let item = Item(name: "Test")
    context.insert(item)
    try context.saveChanges(operation: .itemEdit)
    #expect(item.status == .unchecked)

    item.toggleStatus()
    #expect(item.status == .checked)

    item.toggleStatus()
    #expect(item.status == .unchecked)
  }

  @Test("uncheckAllItems() clears every checked item and leaves the rest alone")
  func uncheckAllItems() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = Checklist(name: "Test", sortKey: 1.0)
    context.insert(checklist)

    let checkedOne = Item(name: "one", sortKey: 1.0)
    checkedOne.status = .checked
    context.insert(checkedOne)
    checkedOne.checklist = checklist

    let checkedTwo = Item(name: "two", sortKey: 2.0)
    checkedTwo.status = .checked
    context.insert(checkedTwo)
    checkedTwo.checklist = checklist

    let uncheckedItem = Item(name: "three", sortKey: 3.0)
    context.insert(uncheckedItem)
    uncheckedItem.checklist = checklist

    try context.saveChanges(operation: .itemEdit)

    checklist.uncheckAllItems()
    try context.saveChanges(operation: .itemEdit)

    #expect(checklist.items.allSatisfy { $0.status == .unchecked })
  }

  // MARK: - dragItems() NSItemProvider round trip

  /// The `.timeLimit` stands in for the explicit `wait(for:timeout: 5)` the XCTest version used.
  /// A minute is far coarser than five seconds, but it is the finest granularity the trait offers
  /// and it still bounds a provider that never calls back, which is the failure worth catching.
  @Test("a checklist's drag payload round-trips its id", .timeLimit(.minutes(1)))
  func checklistDragItemsRoundTripsId() async throws {
    let context = try TestModelContainer.makeContext()
    let checklist = Checklist(name: "Test")
    context.insert(checklist)
    try context.saveChanges(operation: .checklistEdit)

    let dragItems = checklist.dragItems()
    #expect(dragItems.count == 1)

    let payload = try await loadPlainTextPayload(from: dragItems[0].itemProvider)
    #expect(payload == checklist.id)
  }

  @Test("an item's drag payload round-trips its id", .timeLimit(.minutes(1)))
  func itemDragItemsRoundTripsId() async throws {
    let context = try TestModelContainer.makeContext()
    let item = Item(name: "Test")
    context.insert(item)
    try context.saveChanges(operation: .itemEdit)

    let dragItems = item.dragItems()
    #expect(dragItems.count == 1)

    let payload = try await loadPlainTextPayload(from: dragItems[0].itemProvider)
    #expect(payload == item.id)
  }

  /// Drives the async `NSItemProvider` data-representation callback registered by `dragItems()`
  /// and decodes the resulting UTF-8 payload.
  ///
  /// The callback is `@Sendable` because the system can invoke it off the main actor, which also
  /// opts it out of this target's main-actor default. Everything it touches is the continuation,
  /// which is safe to resume from anywhere.
  private func loadPlainTextPayload(from itemProvider: NSItemProvider) async throws -> String {
    let data: Data? = try await withCheckedThrowingContinuation { continuation in
      itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { @Sendable data, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: data)
        }
      }
    }

    let payloadData = try #require(data, "loadDataRepresentation returned neither data nor an error")
    return try #require(String(data: payloadData, encoding: .utf8), "the drag payload was not valid UTF-8")
  }
}
