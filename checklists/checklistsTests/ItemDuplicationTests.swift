//
//  ItemDuplicationTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing

/// Covers `ModelContext.duplicate(item:in:)`.
///
/// No isolation annotation — AGENTS.md §"Concurrency".
@Suite("Duplicating an item")
struct ItemDuplicationTests {
  /// A checklist with `itemCount` items, the first `checkedCount` of them checked.
  private func makeChecklist(itemCount: Int, checkedCount: Int = 0, in context: ModelContext) throws -> Checklist {
    let checklist = Checklist(name: "Packing", sortKey: 1.0)
    context.insert(checklist)
    for index in 0 ..< itemCount {
      let item = Item(name: "Item \(index)", notes: index == 1 ? "With a note." : nil, sortKey: Double(index + 1))
      item.status = index < checkedCount ? .checked : .unchecked
      context.insert(item)
      item.checklist = checklist
    }
    try context.saveChanges(operation: .sampleSeed)
    return checklist
  }

  @Test("the copy carries the name and notes, unchanged")
  func copiesNameAndNotes() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 2, in: context)
    let source = checklist.items[1]

    let copy = try context.duplicate(item: source, in: checklist)

    #expect(copy.id != source.id)
    #expect(copy.name == source.name)
    #expect(copy.notes == source.notes)
  }

  /// Unlike a checklist copy, an item's name is never suffixed — there is no collision to
  /// disambiguate.
  @Test("the copy's name has no added suffix")
  func nameHasNoSuffix() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 1, in: context)
    let source = checklist.items[0]

    let copy = try context.duplicate(item: source, in: checklist)

    #expect(copy.name == "Item 0")
  }

  @Test("the copy starts unchecked, however checked the original was")
  func copyStartsUnchecked() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 2, checkedCount: 2, in: context)
    let source = checklist.items[0]

    let copy = try context.duplicate(item: source, in: checklist)

    #expect(copy.status == .unchecked)
    #expect(source.status == .checked) // the original is left exactly as it was found.
  }

  @Test("the copy lands directly after the original")
  func copyLandsAfterTheOriginal() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 3, in: context)
    let source = checklist.items[0]

    let copy = try context.duplicate(item: source, in: checklist)

    let orderedIds: [String] = checklist.items.map(\.id)
    let expectedIds: [String] = [source.id, copy.id, checklist.items[2].id, checklist.items[3].id]
    #expect(orderedIds == expectedIds)
  }

  @Test("duplicating the last item puts the copy at the end")
  func copyOfLastLandsAtTheEnd() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 2, in: context)
    let source = checklist.items[1]

    let copy = try context.duplicate(item: source, in: checklist)

    let orderedIds: [String] = checklist.items.map(\.id)
    #expect(orderedIds.last == copy.id)
    #expect(orderedIds.count == 3)
  }

  /// The side effect that makes duplication behave like any other edit: a completed checklist is
  /// no longer complete once a checked item gains an unchecked sibling.
  @Test("duplicating a checked item un-completes a completed checklist")
  func duplicatingChecksOutCompletion() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 1, checkedCount: 1, in: context)
    #expect(checklist.isComplete)

    try context.duplicate(item: checklist.items[0], in: checklist)

    #expect(!checklist.isComplete)
  }

  @Test("blank items can be duplicated too")
  func blankItemsCanBeDuplicated() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 0, in: context)
    let blank = Item(sortKey: 1.0)
    context.insert(blank)
    blank.checklist = checklist
    try context.saveChanges(operation: .sampleSeed)

    let copy = try context.duplicate(item: blank, in: checklist)

    #expect(copy.isBlank)
    #expect(checklist.items.count == 2)
  }
}
