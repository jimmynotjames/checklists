//
//  ChecklistDuplicationTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing

/// Covers `ModelContext.duplicate(checklist:among:)` and the naming rules behind it.
///
/// The names these produce are localized, and `make test-unit` does not pin a locale, so nothing
/// here asserts English text. The rules are asserted structurally instead — that a copy's name is
/// derived from the original's, that a clash resolves to something unused — which holds in every
/// locale and does not break the day a translation is revised.
///
/// No isolation annotation — AGENTS.md §"Concurrency".
@Suite("Duplicating a checklist")
struct ChecklistDuplicationTests {
  /// A checklist with `itemCount` items, the first `checkedCount` of them checked, and a note on
  /// the second.
  private func makeChecklist(
    name: String = "Packing",
    itemCount: Int,
    checkedCount: Int = 0,
    sortKey: Double = 1.0,
    in context: ModelContext
  ) throws -> Checklist {
    let checklist = Checklist(name: name, notes: "Before the ferry.", sortKey: sortKey)
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

  // MARK: - The copy itself

  @Test("the copy carries the notes and every item, in order")
  func copiesTheGraph() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 3, in: context)

    let copy = try context.duplicate(checklist: source, among: [source])

    #expect(copy.id != source.id)
    #expect(copy.notes == source.notes)
    let copiedNames: [String] = copy.items.map(\.name)
    let copiedNotes: [String?] = copy.items.map(\.notes)
    #expect(copiedNames == ["Item 0", "Item 1", "Item 2"])
    #expect(copiedNotes == [nil, "With a note.", nil])
  }

  /// The decision that makes this a *clean* copy rather than a clone: a duplicate has never been
  /// run, whatever state the original was left in.
  @Test("every copied item starts unchecked, however checked the original was")
  func copiedItemsStartUnchecked() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 3, checkedCount: 3, in: context)
    #expect(source.isComplete)

    let copy = try context.duplicate(checklist: source, among: [source])

    #expect(copy.items.allSatisfy { $0.status == .unchecked })
    #expect(copy.percentageComplete == 0.0)
    // And the original is left exactly as it was found.
    #expect(source.items.allSatisfy { $0.status == .checked })
  }

  /// Both stamps record something that happened to the *original*. Copying them would have the
  /// copy claim a completion it was never part of — see core-docs/persistence-design.md §Model.
  @Test("neither history stamp is carried over, and neither is disturbed on the original")
  func historyStampsAreNotCopied() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 2, checkedCount: 2, in: context)
    let updatedAt = Date(timeIntervalSinceReferenceDate: 1000.0)
    let completedAt = Date(timeIntervalSinceReferenceDate: 2000.0)
    source.recordUpdate(at: updatedAt)
    source.recordCompletion(at: completedAt)

    let copy = try context.duplicate(checklist: source, among: [source])

    #expect(copy.lastUpdated == nil)
    #expect(copy.lastCompleted == nil)
    #expect(source.lastUpdated == updatedAt)
    #expect(source.lastCompleted == completedAt)
  }

  /// The scratch row the detail screen seeds and trims is not a task, so a copy does not inherit
  /// someone's abandoned one.
  @Test("blank rows are left behind")
  func blankItemsAreSkipped() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 2, in: context)
    let blank = Item(sortKey: 99.0)
    context.insert(blank)
    blank.checklist = source
    try context.saveChanges(operation: .sampleSeed)

    let copy = try context.duplicate(checklist: source, among: [source])

    #expect(copy.items.count == 2)
    #expect(source.items.count == 3)
  }

  @Test("a checklist holding nothing but a blank row copies to an empty one")
  func onlyBlankRowCopiesToEmpty() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 0, in: context)
    let blank = Item(sortKey: 1.0)
    context.insert(blank)
    blank.checklist = source
    try context.saveChanges(operation: .sampleSeed)

    let copy = try context.duplicate(checklist: source, among: [source])

    #expect(copy.items.isEmpty)
  }

  /// The two graphs must be genuinely separate, or the cascade delete rule would take the
  /// original's items with the copy's.
  @Test("deleting the copy leaves the original's items alone")
  func copyIsIndependentOfTheOriginal() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 3, in: context)
    let copy = try context.duplicate(checklist: source, among: [source])

    context.delete(copy)
    try context.saveChanges(operation: .delete)

    let remainingItems = try context.fetch(FetchDescriptor<Item>())
    #expect(source.items.count == 3)
    #expect(remainingItems.count == 3)
  }

  // MARK: - Placement

  @Test("the copy lands directly after the original")
  func copyLandsAfterTheOriginal() throws {
    let context = try TestModelContainer.makeContext()
    let first = try makeChecklist(name: "Packing", itemCount: 1, sortKey: 1.0, in: context)
    let second = try makeChecklist(name: "Groceries", itemCount: 1, sortKey: 2.0, in: context)
    let third = try makeChecklist(name: "Chores", itemCount: 1, sortKey: 3.0, in: context)

    let copy = try context.duplicate(checklist: first, among: [first, second, third])

    let orderedIds: [String] = try context.fetchChecklistsSorted().map(\.id)
    let expectedIds: [String] = [first.id, copy.id, second.id, third.id]
    #expect(orderedIds == expectedIds)
  }

  @Test("duplicating the last checklist puts the copy at the end")
  func copyOfLastLandsAtTheEnd() throws {
    let context = try TestModelContainer.makeContext()
    let first = try makeChecklist(name: "Packing", itemCount: 1, sortKey: 1.0, in: context)
    let second = try makeChecklist(name: "Groceries", itemCount: 1, sortKey: 2.0, in: context)

    let copy = try context.duplicate(checklist: second, among: [first, second])

    let orderedIds: [String] = try context.fetchChecklistsSorted().map(\.id)
    let expectedIds: [String] = [first.id, second.id, copy.id]
    #expect(orderedIds == expectedIds)
  }

  // MARK: - Naming

  @Test("the copy is named after the original, but not identically")
  func copyNameIsDerivedFromTheOriginal() {
    let name = ChecklistCopyNaming.name(forCopyOf: "Packing", existingNames: ["Packing"])

    #expect(name != "Packing")
    #expect(name.contains("Packing"))
  }

  @Test("a name already taken is disambiguated")
  func clashingNameIsDisambiguated() {
    let first = ChecklistCopyNaming.name(forCopyOf: "Packing", existingNames: ["Packing"])
    let second = ChecklistCopyNaming.name(forCopyOf: "Packing", existingNames: ["Packing", first])

    #expect(second != first)
    #expect(second.contains("Packing"))
  }

  @Test("each further copy gets its own name")
  func repeatedCopiesEachGetTheirOwnName() {
    var taken: Set = ["Packing"]
    for _ in 0 ..< 5 {
      let name = ChecklistCopyNaming.name(forCopyOf: "Packing", existingNames: taken)
      #expect(!taken.contains(name))
      taken.insert(name)
    }
    #expect(taken.count == 6)
  }

  /// Duplicating through the list screen twice in a row is the path this covers: the second copy
  /// must not collide with the first.
  @Test("duplicating the same checklist twice produces two distinct names")
  func duplicatingTwiceProducesDistinctNames() throws {
    let context = try TestModelContainer.makeContext()
    let source = try makeChecklist(itemCount: 2, in: context)

    let first = try context.duplicate(checklist: source, among: context.fetchChecklistsSorted())
    let second = try context.duplicate(checklist: source, among: context.fetchChecklistsSorted())

    #expect(first.name != second.name)
    #expect(first.name != source.name)
  }

  /// See `ChecklistCopyNaming` for why the suffix is never parsed back out of a name.
  @Test("a copy of a copy keeps the earlier name whole")
  func copyOfACopyKeepsTheEarlierNameWhole() {
    let first = ChecklistCopyNaming.name(forCopyOf: "Packing", existingNames: ["Packing"])
    let second = ChecklistCopyNaming.name(forCopyOf: first, existingNames: ["Packing", first])

    #expect(second.contains(first))
  }

  /// A checklist saved with an empty name reads as "untitled checklist" everywhere else; " copy"
  /// on its own would name nothing.
  @Test("an unnamed checklist copies under the untitled name")
  func unnamedChecklistUsesTheUntitledFallback() {
    let name = ChecklistCopyNaming.name(forCopyOf: "", existingNames: [""])

    #expect(name.contains(CommonStrings.defaultChecklistName))
  }
}
