//
//  ChecklistBulkActionsTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing

/// Covers the Checklists screen's multi-checklist actions and the move-action edge rules.
///
/// Copy names are localized and `make test-unit` pins no locale, so nothing here asserts English
/// text — only that names are distinct and derived from the source.
///
/// No isolation annotation — AGENTS.md §"Concurrency".
@Suite("Checklist bulk actions")
struct ChecklistBulkActionsTests {
  /// Saved checklists in the given order, each with one item, checked when `checked` is true.
  private func makeChecklists(
    _ names: [String],
    checked: Bool = false,
    in context: ModelContext,
  ) throws -> [Checklist] {
    let checklists = names.enumerated().map { index, name in
      Checklist(name: name, sortKey: Double(index + 1))
    }
    for checklist in checklists {
      context.insert(checklist)
      let item = Item(name: "Item", sortKey: 1.0)
      item.status = checked ? .checked : .unchecked
      context.insert(item)
      item.checklist = checklist
    }
    try context.saveChanges(operation: .sampleSeed)
    return checklists
  }

  // MARK: - Delete

  @Test("delete removes the named checklists and skips ids that are already gone")
  func deleteSkipsMissing() throws {
    let context = try TestModelContainer.makeContext()
    let lists = try makeChecklists(["A", "B", "C"], in: context)

    let deleted = context.deleteChecklists(ids: [lists[0].id, lists[2].id, "deleted-elsewhere"])

    #expect(deleted == 2)
    #expect(try context.fetchChecklistsSorted().map(\.name) == ["B"])
  }

  /// Two records can share an `id` until sample dedupe runs. Swipe-to-delete must remove the row the
  /// user swiped, and once that record is gone must not fall back to its twin.
  @Test("delete by record removes exactly that twin, and never the other")
  func deleteByRecordSparesTwin() throws {
    let context = try TestModelContainer.makeContext()
    let twins = try makeChecklists(["Swiped", "Kept"], in: context)
    twins[1].id = twins[0].id
    try context.saveChanges(operation: .checklistEdit)
    let swiped = twins[0].persistentModelID

    #expect(context.deleteChecklists([swiped]) == 1)
    #expect(try context.fetchChecklistsSorted().map(\.name) == ["Kept"])

    #expect(context.deleteChecklists([swiped]) == 0)
    #expect(try context.fetchChecklistsSorted().map(\.name) == ["Kept"])
  }

  // MARK: - Duplicate

  @Test("each copy lands directly after its own source")
  func duplicatePlacesCopiesAfterSources() throws {
    let context = try TestModelContainer.makeContext()
    let lists = try makeChecklists(["A", "B", "C"], in: context)

    let copied = context.duplicateChecklists(ids: [lists[0].id, lists[1].id])

    #expect(copied == 2)
    let order = try context.fetchChecklistsSorted()
    #expect(order.count == 5)
    #expect(order[0].id == lists[0].id)
    #expect(order[2].id == lists[1].id)
    #expect(order[4].id == lists[2].id)
    #expect(order[1].name.contains("A"))
    #expect(order[3].name.contains("B"))
  }

  /// The re-fetch between copies is what keeps this from producing two identically named copies.
  @Test("two selected checklists sharing a name get differently named copies")
  func duplicateOfSameNamedChecklistsStaysDistinct() throws {
    let context = try TestModelContainer.makeContext()
    let lists = try makeChecklists(["Packing", "Packing"], in: context)

    context.duplicateChecklists(ids: Set(lists.map(\.id)))

    let names = try context.fetchChecklistsSorted().map(\.name)
    #expect(names.count == 4)
    #expect(Set(names).count == 3) // the two originals share a name; the copies must not
  }

  // MARK: - Reset

  @Test("reset unchecks only the given checklists")
  func resetUnchecksGiven() throws {
    let context = try TestModelContainer.makeContext()
    let lists = try makeChecklists(["A", "B"], checked: true, in: context)

    #expect(context.resetChecklists([lists[0]]) == 1)

    #expect(lists[0].items.allSatisfy { $0.status == .unchecked })
    #expect(lists[1].items.allSatisfy { $0.status == .checked })
  }

  @Test("reset reports nothing done when nothing was checked")
  func resetWithNothingChecked() throws {
    let context = try TestModelContainer.makeContext()
    let lists = try makeChecklists(["A"], in: context)

    #expect(context.resetChecklists(lists) == 0)
    #expect(context.resetChecklists([]) == 0)
  }

  // MARK: - Move actions

  @Test("move destinations in the middle of the list")
  func moveDestinationsInMiddle() {
    #expect(ChecklistMoveAction.up.destination(from: 2, count: 5) == 1)
    #expect(ChecklistMoveAction.down.destination(from: 2, count: 5) == 3)
    #expect(ChecklistMoveAction.top.destination(from: 2, count: 5) == 0)
    #expect(ChecklistMoveAction.bottom.destination(from: 2, count: 5) == 4)
  }

  @Test("moves that would go nowhere are not offered")
  func moveDestinationsAtEdges() {
    #expect(ChecklistMoveAction.up.destination(from: 0, count: 5) == nil)
    #expect(ChecklistMoveAction.top.destination(from: 0, count: 5) == nil)
    #expect(ChecklistMoveAction.down.destination(from: 4, count: 5) == nil)
    #expect(ChecklistMoveAction.bottom.destination(from: 4, count: 5) == nil)
    for action in ChecklistMoveAction.allCases {
      #expect(action.destination(from: 0, count: 1) == nil)
    }
  }

  @Test("a move action lands the checklist where it says")
  func moveActionAgreesWithMove() throws {
    let context = try TestModelContainer.makeContext()
    _ = try makeChecklists(["A", "B", "C", "D"], in: context)

    for (action, expected) in [
      (ChecklistMoveAction.down, ["A", "C", "B", "D"]),
      (.bottom, ["A", "B", "D", "C"]),
      (.top, ["B", "A", "D", "C"]),
      (.up, ["A", "B", "D", "C"]),
    ] {
      // Each step moves whichever checklist is second, so the edge cases are all exercised.
      let siblings = try context.fetchChecklistsSorted()
      let destination = try #require(action.destination(from: 1, count: siblings.count))
      try context.move(checklist: siblings[1], among: siblings, to: destination)
      #expect(try context.fetchChecklistsSorted().map(\.name) == expected, "\(action)")
    }
  }
}
