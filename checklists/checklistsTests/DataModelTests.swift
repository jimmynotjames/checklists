//
//  DataModelTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing

/// Covers the `@Model` types themselves — persistence round-trips, `percentageComplete`, and the
/// cascade delete rule between `Checklist` and `Item`.
///
/// No isolation annotation — AGENTS.md §"Concurrency".
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

  @Test("the history timestamps round-trip, and a new checklist has neither")
  func historyTimestampsPersist() throws {
    let context = try makeContext()
    let fresh = Checklist(name: "Groceries", sortKey: 1.0)
    #expect(fresh.lastUpdated == nil)
    #expect(fresh.lastCompleted == nil)

    let updated = Date(timeIntervalSinceReferenceDate: 1000.0)
    let completed = Date(timeIntervalSinceReferenceDate: 2000.0)
    fresh.recordUpdate(at: updated)
    fresh.recordCompletion(at: completed)
    context.insert(fresh)
    try context.saveChanges(operation: .itemUpdate)

    let fetched = try context.fetchChecklistsSorted().first
    #expect(fetched?.lastUpdated == updated)
    #expect(fetched?.lastCompleted == completed)
  }

  @Test("isComplete needs every item checked, and at least one item")
  func isCompleteRequiresItems() throws {
    let context = try makeContext()
    let checklist = Checklist(name: "Packing", sortKey: 1.0)
    context.insert(checklist)
    // An empty list reads 0%, not 100% — so it is never complete, which is what keeps deleting
    // every item from counting as finishing the list.
    #expect(checklist.isComplete == false)

    let first = Item(name: "Passport", sortKey: 1.0)
    let second = Item(name: "Tickets", sortKey: 2.0)
    for item in [first, second] {
      context.insert(item)
      item.checklist = checklist
    }
    #expect(checklist.isComplete == false)

    first.status = .checked
    #expect(checklist.isComplete == false)

    second.status = .checked
    #expect(checklist.isComplete)
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
