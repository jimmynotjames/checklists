//
//  ModelBehaviorTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import UniformTypeIdentifiers
import XCTest

/// Covers the ordering/mutation methods that replace Realm's `List` mutators (`Reordering.swift`),
/// plus `Item.toggleStatus()`, `Checklist.uncheckAllItems()`, and the `dragItems()` `NSItemProvider`
/// round trip on both model types.
///
/// See the doc comment on `DataModelTests` for why this class is `nonisolated` at the type level
/// with individual `@MainActor` test methods.
///
/// Reorder tests assert the resulting **order** via `fetchChecklistsSorted()` / `checklist.items`
/// rather than specific `sortKey` values — the values are an implementation detail of
/// `SortKeyReorder`, already covered directly by `SortKeyReorderTests`.
nonisolated final class ModelBehaviorTests: XCTestCase {
  @MainActor private func makeContext() throws -> ModelContext {
    try ModelContext(TestModelContainer.make())
  }

  // MARK: - Checklist reordering

  @MainActor func testMoveChecklistReordersByKey() throws {
    let context = try makeContext()
    let checklistA = Checklist(name: "A", sortKey: 1.0)
    let checklistB = Checklist(name: "B", sortKey: 2.0)
    let checklistC = Checklist(name: "C", sortKey: 3.0)
    for checklist in [checklistA, checklistB, checklistC] {
      context.insert(checklist)
    }
    try context.saveChanges(operation: .checklistEdit)

    // Move A to the end: [A, B, C] -> [B, C, A].
    try context.move(checklist: checklistA, among: [checklistA, checklistB, checklistC], to: 2)

    XCTAssertEqual(try context.fetchChecklistsSorted().map(\.name), ["B", "C", "A"])
  }

  @MainActor func testInsertChecklistAtTop() throws {
    let context = try makeContext()
    let existingOne = Checklist(name: "Existing One", sortKey: 1.0)
    let existingTwo = Checklist(name: "Existing Two", sortKey: 2.0)
    context.insert(existingOne)
    context.insert(existingTwo)
    try context.saveChanges(operation: .checklistEdit)

    let newChecklist = Checklist(name: "New")
    try context.insert(checklist: newChecklist, at: 0, among: [existingOne, existingTwo])

    XCTAssertEqual(try context.fetchChecklistsSorted().map(\.name), ["New", "Existing One", "Existing Two"])
  }

  // MARK: - Item reordering

  @MainActor func testMoveItemReordersByKey() throws {
    let context = try makeContext()
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

    XCTAssertEqual(checklist.items.map(\.name), ["two", "three", "one"])
  }

  // MARK: - Status mutation

  @MainActor func testToggleStatus() throws {
    let context = try makeContext()
    let item = Item(name: "Test")
    context.insert(item)
    try context.saveChanges(operation: .itemEdit)
    XCTAssertEqual(item.status, .unchecked)

    item.toggleStatus()
    XCTAssertEqual(item.status, .checked)

    item.toggleStatus()
    XCTAssertEqual(item.status, .unchecked)
  }

  @MainActor func testUncheckAllItems() throws {
    let context = try makeContext()
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

    XCTAssertTrue(checklist.items.allSatisfy { $0.status == .unchecked })
  }

  // MARK: - dragItems() NSItemProvider round trip

  @MainActor func testChecklistDragItemsRoundTripsId() throws {
    let context = try makeContext()
    let checklist = Checklist(name: "Test")
    context.insert(checklist)
    try context.saveChanges(operation: .checklistEdit)

    let dragItems = checklist.dragItems()
    XCTAssertEqual(dragItems.count, 1)

    let payload = try loadPlainTextPayload(from: dragItems[0].itemProvider)
    XCTAssertEqual(payload, checklist.id)
  }

  @MainActor func testItemDragItemsRoundTripsId() throws {
    let context = try makeContext()
    let item = Item(name: "Test")
    context.insert(item)
    try context.saveChanges(operation: .itemEdit)

    let dragItems = item.dragItems()
    XCTAssertEqual(dragItems.count, 1)

    let payload = try loadPlainTextPayload(from: dragItems[0].itemProvider)
    XCTAssertEqual(payload, item.id)
  }

  /// Drives the async `NSItemProvider` data-representation callback registered by `dragItems()`
  /// and decodes the resulting UTF-8 payload synchronously for the test.
  private func loadPlainTextPayload(from itemProvider: NSItemProvider) throws -> String {
    let expectation = expectation(description: "plain text data representation loaded")
    var result: Result<String, Error> = .failure(placeholderError)

    itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { data, error in
      if let error {
        result = .failure(error)
      } else if let data, let string = String(data: data, encoding: .utf8) {
        result = .success(string)
      } else {
        result = .failure(placeholderError)
      }
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5)
    return try result.get()
  }
}

/// Placeholder `Error` used only to seed `Result`'s initial value before the async callback in
/// `loadPlainTextPayload(from:)` runs; never surfaced to a passing test. `nonisolated` because
/// it's read from that callback, which the system can invoke off the main actor.
nonisolated private let placeholderError = NSError(domain: "ModelBehaviorTests", code: -1)
