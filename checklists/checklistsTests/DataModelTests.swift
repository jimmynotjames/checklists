//
//  DataModelTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import Testing

/// Covers the `@Model` types themselves — persistence round-trips, `percentageComplete`, and the
/// cascade delete rule between `Checklist` and `Item`.
///
/// No isolation annotation: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` already makes this struct
/// and its `@Test` methods main-actor isolated, which is what the SwiftData code under test
/// requires. Unlike an `XCTestCase` subclass there is no nonisolated base class to collide with,
/// so the target's default is simply correct here.
@Suite("Checklist and Item model behaviour")
struct DataModelTests {
  private func makeContext() throws -> ModelContext {
    try ModelContext(TestModelContainer.make())
  }

  @Test("a checklist round-trips through the store with every field intact")
  func checklistPersistsAndFetches() throws {
    let context = try makeContext()
    let checklist = Checklist(name: "Groceries", notes: "Weekly", sortKey: 1.0)
    context.insert(checklist)
    try context.saveChanges(operation: .checklistEdit)

    let fetched = try context.fetchChecklistsSorted()
    #expect(fetched.count == 1)
    #expect(fetched.first?.id == checklist.id)
    #expect(fetched.first?.name == "Groceries")
    #expect(fetched.first?.notes == "Weekly")
    #expect(fetched.first?.sortKey == 1.0)
  }

  @Test("an item round-trips with its status and its parent link")
  func itemPersistsWithStatus() throws {
    let context = try makeContext()
    let checklist = Checklist(name: "Packing", sortKey: 1.0)
    context.insert(checklist)
    let item = Item(name: "Passport", notes: "in the drawer", sortKey: 1.0)
    item.status = .checked
    context.insert(item)
    item.checklist = checklist
    try context.saveChanges(operation: .itemEdit)

    let fetchedItem = try #require(context.item(id: item.id))
    #expect(fetchedItem.name == "Passport")
    #expect(fetchedItem.notes == "in the drawer")
    #expect(fetchedItem.status == .checked)
    #expect(fetchedItem.checklist?.id == checklist.id)
  }

  @Test("an empty checklist is 0% complete rather than undefined")
  func percentageCompleteEmptyIsZero() throws {
    let context = try makeContext()
    let checklist = Checklist(name: "Empty", sortKey: 1.0)
    context.insert(checklist)
    try context.saveChanges(operation: .checklistEdit)

    #expect(checklist.percentageComplete == 0.0)
  }

  @Test("one of two checked items is 50% complete")
  func percentageCompleteHalf() throws {
    let context = try makeContext()
    let checklist = Checklist(name: "Half", sortKey: 1.0)
    context.insert(checklist)

    let checkedItem = Item(name: "Done", sortKey: 1.0)
    checkedItem.status = .checked
    context.insert(checkedItem)
    checkedItem.checklist = checklist

    let uncheckedItem = Item(name: "Not done", sortKey: 2.0)
    context.insert(uncheckedItem)
    uncheckedItem.checklist = checklist

    try context.saveChanges(operation: .itemEdit)

    #expect(abs(checklist.percentageComplete - 0.5) < 0.0001)
  }

  @Test("deleting a checklist cascades to its items")
  func deletingChecklistCascadesItems() throws {
    let context = try makeContext()
    let checklist = Checklist(name: "Doomed", sortKey: 1.0)
    context.insert(checklist)

    let itemOne = Item(name: "one", sortKey: 1.0)
    context.insert(itemOne)
    itemOne.checklist = checklist

    let itemTwo = Item(name: "two", sortKey: 2.0)
    context.insert(itemTwo)
    itemTwo.checklist = checklist

    try context.saveChanges(operation: .checklistEdit)
    #expect(try context.fetch(FetchDescriptor<Item>()).count == 2)

    context.delete(checklist)
    try context.saveChanges(operation: .delete)

    #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
  }
}
