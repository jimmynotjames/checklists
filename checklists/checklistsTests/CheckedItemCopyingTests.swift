//
//  CheckedItemCopyingTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing

/// Covers `Checklist.checkedItems` and the `ModelContext.copyCheckedItems` and
/// `moveCheckedItems` operations behind the detail screen's "Copy Checked Items to…" and "Move
/// Checked Items to…" entries.
///
/// The new checklist's name is chosen by the picker, not by these operations, so nothing here
/// asserts localized text — unlike `ChecklistDuplicationTests`, which has naming rules to cover.
///
/// No isolation annotation — AGENTS.md §"Concurrency".
@Suite("Copying checked items")
struct CheckedItemCopyingTests {
  /// A checklist whose items are named `<itemPrefix> 0…`, with `checkedIndices` ticked and a note
  /// on the second. Give a destination its own prefix so an append assertion says which list each
  /// row came from.
  private func makeChecklist(
    name: String = "Packing",
    itemPrefix: String = "Item",
    itemCount: Int,
    checkedIndices: Set<Int> = [],
    sortKey: Double = 1.0,
    in context: ModelContext
  ) throws -> Checklist {
    let checklist = Checklist(name: name, notes: "Before the ferry.", sortKey: sortKey)
    context.insert(checklist)
    for index in 0 ..< itemCount {
      let item = Item(name: "\(itemPrefix) \(index)", notes: index == 1 ? "With a note." : nil, sortKey: Double(index + 1))
      item.status = checkedIndices.contains(index) ? .checked : .unchecked
      context.insert(item)
      item.checklist = checklist
    }
    try context.saveChanges(operation: .sampleSeed)
    return checklist
  }

  // MARK: - What counts as checked

  @Test("only ticked items are offered for copying")
  func checkedItemsAreTheTickedOnes() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 4, checkedIndices: [0, 2], in: context)

    #expect(source.checkedItems.map(\.name) == ["Item 0", "Item 2"])
  }

  /// The scratch row the detail screen seeds can be ticked like any other, and copying it would
  /// carry an empty row into the destination. It is also what makes the menu entry's "is there
  /// anything to copy" check honest.
  @Test("a ticked blank row does not count")
  func tickedBlankRowIsNotCounted() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 1, in: context)
    let blank = Item(sortKey: 99.0)
    blank.status = .checked
    context.insert(blank)
    blank.checklist = source
    try context.saveChanges(operation: .sampleSeed)

    #expect(source.checkedItems.isEmpty)
  }

  // MARK: - Into a new checklist

  @Test("the new checklist carries the ticked items only, in order, with their notes")
  func newChecklistCarriesTheTickedItems() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 4, checkedIndices: [1, 3], in: context)

    let destination = try context.copyCheckedItems(of: source, intoChecklistNamed: "Ferry", among: [source])

    #expect(destination.name == "Ferry")
    #expect(destination.items.map(\.name) == ["Item 1", "Item 3"])
    #expect(destination.items.map(\.notes) == ["With a note.", nil])
  }

  /// The point of the feature is a fresh list to run, so the copies arrive as tasks outstanding —
  /// the same call both existing copy paths make.
  @Test("copied items arrive unchecked, and the source keeps its ticks")
  func copiesArriveUncheckedAndSourceIsUntouched() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 3, checkedIndices: [0, 1, 2], in: context)

    let destination = try context.copyCheckedItems(of: source, intoChecklistNamed: "Ferry", among: [source])

    #expect(destination.items.allSatisfy { $0.status == .unchecked })
    #expect(source.items.allSatisfy { $0.status == .checked })
    #expect(source.items.count == 3, "The source must not lose the items it was copied from.")
  }

  /// Both stamps record something that happened to the source. Nothing has been run on the new
  /// list yet, and the source was only read.
  @Test("neither history stamp is set on the new checklist, nor disturbed on the source")
  func historyStampsAreUntouched() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 2, checkedIndices: [0, 1], in: context)
    let updatedAt = Date(timeIntervalSinceReferenceDate: 1000.0)
    let completedAt = Date(timeIntervalSinceReferenceDate: 2000.0)
    source.recordUpdate(at: updatedAt)
    source.recordCompletion(at: completedAt)

    let destination = try context.copyCheckedItems(of: source, intoChecklistNamed: "Ferry", among: [source])

    #expect(destination.lastUpdated == nil)
    #expect(destination.lastCompleted == nil)
    #expect(source.lastUpdated == updatedAt)
    #expect(source.lastCompleted == completedAt)
  }

  /// Deliberately unlike `duplicate(checklist:among:)`, which places its copy beside the original:
  /// this list is a sibling of nothing and carries a name the person has to find in order to
  /// change, so it goes where a new checklist goes.
  @Test("the new checklist lands at the top of the list")
  func newChecklistLandsAtTheTop() throws {
    let context = try TestModelContainer.makeContext()
    let first = try makeChecklist(name: "Packing", itemCount: 2, checkedIndices: [0], sortKey: 1.0, in: context)
    let second = try makeChecklist(name: "Groceries", itemCount: 1, sortKey: 2.0, in: context)
    let third = try makeChecklist(name: "Chores", itemCount: 1, sortKey: 3.0, in: context)

    let destination = try context.copyCheckedItems(
      of: first,
      intoChecklistNamed: "Ferry",
      among: [first, second, third]
    )

    let orderedIds: [String] = try context.fetchChecklistsSorted().map(\.id)
    let expectedIds: [String] = [destination.id, first.id, second.id, third.id]
    #expect(orderedIds == expectedIds)
  }

  /// The two graphs must be genuinely separate, or the cascade delete rule would take the source's
  /// items with the new list's.
  @Test("deleting the new checklist leaves the source's items alone")
  func newChecklistIsIndependentOfTheSource() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 3, checkedIndices: [0, 1], in: context)
    let destination = try context.copyCheckedItems(of: source, intoChecklistNamed: "Ferry", among: [source])

    context.delete(destination)
    try context.saveChanges(operation: .delete)

    let remainingItems = try context.fetch(FetchDescriptor<Item>())
    #expect(source.items.count == 3)
    #expect(remainingItems.count == 3)
  }

  // MARK: - Into an existing checklist

  /// Items normally arrive at the end — the add-item footer appends — and dropping foreign
  /// unchecked rows above a list someone is mid-run on would disturb an order that usually means
  /// sequence.
  @Test("copies are appended after the destination's own items")
  func copiesAreAppendedToAnExistingChecklist() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(name: "Packing", itemCount: 3, checkedIndices: [0, 2], in: context)
    let destination = try makeChecklist(name: "Groceries", itemPrefix: "Grocery", itemCount: 2, sortKey: 2.0, in: context)

    try context.copyCheckedItems(of: source, into: destination)

    #expect(destination.items.map(\.name) == ["Grocery 0", "Grocery 1", "Item 0", "Item 2"])
  }

  @Test("an empty destination takes the copies in order")
  func emptyDestinationTakesTheCopies() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(name: "Packing", itemCount: 3, checkedIndices: [0, 1, 2], in: context)
    let destination = try makeChecklist(name: "Groceries", itemCount: 0, sortKey: 2.0, in: context)

    try context.copyCheckedItems(of: source, into: destination)

    #expect(destination.items.map(\.name) == ["Item 0", "Item 1", "Item 2"])
  }

  @Test("copies into an existing checklist arrive unchecked, whatever state it was in")
  func copiesIntoAnExistingChecklistArriveUnchecked() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(name: "Packing", itemCount: 2, checkedIndices: [0, 1], in: context)
    let destination = try makeChecklist(name: "Groceries", itemCount: 1, checkedIndices: [0], sortKey: 2.0, in: context)
    #expect(destination.isComplete)

    let copies = try context.copyCheckedItems(of: source, into: destination)

    #expect(copies.allSatisfy { $0.status == .unchecked })
    #expect(!destination.isComplete, "Two outstanding items arrived; the list is no longer finished.")
  }

  /// Arriving items are an edit, not a run — `insert(item:at:in:)` does not stamp `lastUpdated`
  /// either — and they are unchecked, so they can only ever make a list less complete.
  @Test("an existing destination's history stamps are left alone")
  func existingDestinationHistoryStampsAreLeftAlone() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(name: "Packing", itemCount: 2, checkedIndices: [0, 1], in: context)
    let destination = try makeChecklist(name: "Groceries", itemCount: 1, checkedIndices: [0], sortKey: 2.0, in: context)
    let completedAt = Date(timeIntervalSinceReferenceDate: 2000.0)
    destination.recordCompletion(at: completedAt)

    try context.copyCheckedItems(of: source, into: destination)

    #expect(destination.lastUpdated == nil)
    #expect(destination.lastCompleted == completedAt)
  }

  @Test("the source is left exactly as it was found")
  func sourceIsUnchangedByAnAppend() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(name: "Packing", itemCount: 3, checkedIndices: [0, 2], in: context)
    let destination = try makeChecklist(name: "Groceries", itemPrefix: "Grocery", itemCount: 1, sortKey: 2.0, in: context)

    try context.copyCheckedItems(of: source, into: destination)

    #expect(source.items.map(\.name) == ["Item 0", "Item 1", "Item 2"])
    #expect(source.checkedItems.map(\.name) == ["Item 0", "Item 2"])
  }

  /// A copy is a save, not a stage: the screens render from the context, so anything left unsaved
  /// would look copied right up until the next launch quietly dropped it.
  @Test("the copies are written to the store, not just staged")
  func copiesArePersisted() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(name: "Packing", itemCount: 2, checkedIndices: [0], in: context)
    let destination = try makeChecklist(name: "Groceries", itemCount: 0, sortKey: 2.0, in: context)

    try context.copyCheckedItems(of: source, into: destination)

    let verification = ModelContext(context.container)
    let destinationId = destination.id
    let persisted = try verification.fetch(FetchDescriptor<Item>())
      .filter { $0.checklist?.id == destinationId }
    #expect(persisted.map(\.name) == ["Item 0"])
  }

  // MARK: - Moving

  @Test("moving into a new checklist takes the ticked items out of the source")
  func moveIntoANewChecklist() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 4, checkedIndices: [1, 3], in: context)

    let destination = try context.moveCheckedItems(of: source, intoChecklistNamed: "Ferry", among: [source])

    #expect(destination.items.map(\.name) == ["Item 1", "Item 3"])
    #expect(destination.items.allSatisfy { $0.status == .unchecked })
    #expect(source.items.map(\.name) == ["Item 0", "Item 2"])
  }

  @Test("moving into an existing checklist appends there and removes here")
  func moveIntoAnExistingChecklist() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(name: "Packing", itemCount: 3, checkedIndices: [0, 2], in: context)
    let destination = try makeChecklist(name: "Groceries", itemPrefix: "Grocery", itemCount: 1, sortKey: 2.0, in: context)

    let copies = try context.moveCheckedItems(of: source, into: destination)

    #expect(copies.map(\.name) == ["Item 0", "Item 2"])
    #expect(destination.items.map(\.name) == ["Grocery 0", "Item 0", "Item 2"])
    #expect(source.items.map(\.name) == ["Item 1"])
  }

  /// A ticked blank row is not a checked item, so it is neither carried nor removed.
  @Test("a move leaves the source's blank row behind")
  func moveLeavesTheBlankRow() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 1, checkedIndices: [0], in: context)
    let blank = Item(sortKey: 99.0)
    blank.status = .checked
    context.insert(blank)
    blank.checklist = source
    try context.saveChanges(operation: .sampleSeed)

    try context.moveCheckedItems(of: source, intoChecklistNamed: "Ferry", among: [source])

    #expect(source.items.count == 1)
    #expect(source.items.first?.isBlank == true)
  }

  /// Deleting is an edit, not a run, and what is left is unchecked, so neither stamp moves.
  @Test("a move leaves the source's history stamps alone")
  func moveLeavesTheSourceStampsAlone() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 2, checkedIndices: [0], in: context)
    let updatedAt = Date(timeIntervalSinceReferenceDate: 1000.0)
    source.recordUpdate(at: updatedAt)

    try context.moveCheckedItems(of: source, intoChecklistNamed: "Ferry", among: [source])

    #expect(source.lastUpdated == updatedAt)
    #expect(source.lastCompleted == nil)
  }

  @Test("both halves of a move are written to the store")
  func moveIsPersisted() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(name: "Packing", itemCount: 2, checkedIndices: [0], in: context)
    let destination = try makeChecklist(name: "Groceries", itemCount: 0, sortKey: 2.0, in: context)

    try context.moveCheckedItems(of: source, into: destination)

    let verification = ModelContext(context.container)
    let persisted = try verification.fetch(FetchDescriptor<Item>())
    let sourceId = source.id
    let destinationId = destination.id
    #expect(persisted.filter { $0.checklist?.id == sourceId }.map(\.name) == ["Item 1"])
    #expect(persisted.filter { $0.checklist?.id == destinationId }.map(\.name) == ["Item 0"])
    #expect(persisted.count == 2, "The moved original is deleted, not orphaned.")
  }
}
