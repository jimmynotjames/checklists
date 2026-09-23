//
//  Reordering.swift
//  checklists
//

import Foundation
import SwiftData

/// A record whose position in a list is user-defined. Lets checklists and items share one
/// reordering implementation.
protocol SortKeyed: AnyObject {
  var sortKey: Double { get set }
}

extension Checklist: SortKeyed {}
extension Item: SortKeyed {}

// MARK: - Ordering operations

extension ModelContext {
  /// Inserts a brand-new checklist at `index` in the user's ordering and saves.
  ///
  /// - Parameter siblings: the existing checklists in display order, **excluding** the new one.
  func insert(checklist: Checklist, at index: Int, among siblings: [Checklist]) throws {
    try insertAndSave(checklist, at: index, among: siblings) {
      try saveChanges(operation: .checklistEdit)
    }
  }

  /// Moves an existing checklist to `index` and saves.
  ///
  /// - Parameter siblings: the checklists in their current display order, **including** the one
  ///   being moved. `index` is the destination in the list as it will look afterwards, matching
  ///   `UITableViewDataSource.tableView(_:moveRowAt:to:)`.
  func move(checklist: Checklist, among siblings: [Checklist], to index: Int) throws {
    guard let remaining = siblingsRemoving(checklist, from: siblings) else { return }
    try placeAndSave(checklist, at: index, among: remaining, restoringSortKeysOf: siblings) {
      try saveChanges(operation: .reorder)
    }
  }

  /// Inserts a brand-new item at `index` within `checklist` and saves.
  func insert(item: Item, at index: Int, in checklist: Checklist) throws {
    try insertAndSave(item, at: index, in: checklist) {
      try saveChanges(operation: .itemEdit)
    }
  }

  /// Moves an existing item within its checklist to `index` and saves.
  func move(item: Item, among siblings: [Item], to index: Int) throws {
    guard let remaining = siblingsRemoving(item, from: siblings) else { return }
    try placeAndSave(item, at: index, among: remaining, restoringSortKeysOf: siblings) {
      try saveChanges(operation: .reorder)
    }
  }

  /// Places `element` and saves, putting every sort key back as it was found if the save fails.
  ///
  /// A move assigns sort keys before it saves, and `place` may renormalize every sibling on the
  /// way, so without this a failed save leaves the context holding an order that was never
  /// written. The screens render from the context rather than from disk, so the new order would
  /// look saved right up until the next launch quietly restored it.
  func placeAndSave<T: SortKeyed>(
    _ element: T,
    at index: Int,
    among others: [T],
    restoringSortKeysOf snapshotSource: [T],
    save: () throws -> Void
  ) throws {
    let snapshot = snapshotSource.map { ($0, $0.sortKey) }
    place(element, at: index, among: others)
    do {
      try save()
    } catch {
      for (record, sortKey) in snapshot {
        record.sortKey = sortKey
      }
      throw error
    }
  }

  /// `insert(checklist:at:among:)` with the save injected, so tests can drive the failure path.
  func insertAndSave(
    _ checklist: Checklist,
    at index: Int,
    among siblings: [Checklist],
    save: () throws -> Void
  ) throws {
    insert(checklist)
    do {
      try placeAndSave(checklist, at: index, among: siblings, restoringSortKeysOf: siblings, save: save)
    } catch {
      // Left registered, the checklist would render as a blank row that was never written, and
      // autosave might yet write it. `placeAndSave` has already put the siblings' keys back.
      delete(checklist)
      throw error
    }
  }

  /// `insert(item:at:in:)` with the save injected, so tests can drive the failure path.
  func insertAndSave(_ item: Item, at index: Int, in checklist: Checklist, save: () throws -> Void) throws {
    let siblings = checklist.items
    insert(item)
    // Setting the child's side of the relationship is what links the two; SwiftData maintains
    // `Checklist.itemsStorage` as the inverse. Assigning both sides would risk a duplicate entry.
    item.checklist = checklist
    do {
      try placeAndSave(item, at: index, among: siblings, restoringSortKeysOf: siblings, save: save)
    } catch {
      // Left in `checklist.items`, the item would put the detail screen's data source one row
      // ahead of its table. Unlinked first so the inverse drops it now rather than at the next
      // save, which is what the table reads before then.
      item.checklist = nil
      delete(item)
      throw error
    }
  }

  // MARK: - Private

  /// `siblings` without `element`, or `nil` when `element` is not among them (a caller bug, or a
  /// stale cache after a sync merge — in both cases doing nothing is the safe response).
  private func siblingsRemoving<T: SortKeyed>(_ element: T, from siblings: [T]) -> [T]? {
    guard let sourceIndex = siblings.firstIndex(where: { $0 === element }) else {
      assertionFailure("Tried to reorder a record that is not in the list it was given.")
      return nil
    }
    var remaining = siblings
    remaining.remove(at: sourceIndex)
    return remaining
  }

  /// Assigns `element` a sort key that puts it at `index` among `others`, renormalizing the list
  /// first if the available gap has been subdivided too far to split again.
  private func place<T: SortKeyed>(_ element: T, at index: Int, among others: [T]) {
    if let key = SortKeyReorder.key(forInsertingAt: index, in: others.map(\.sortKey)) {
      element.sortKey = key
      return
    }

    AppLog.persistence.notice("Sort keys exhausted; renormalizing \(others.count, privacy: .public) records.")
    SortKeyReorder.renormalize(others) { sibling, key in sibling.sortKey = key }

    guard let key = SortKeyReorder.key(forInsertingAt: index, in: others.map(\.sortKey)) else {
      // Unreachable: renormalization leaves gaps of exactly `step`, which is always splittable.
      assertionFailure("No sort key available immediately after renormalizing.")
      element.sortKey = (others.last?.sortKey ?? 0.0) + SortKeyReorder.step
      return
    }
    element.sortKey = key
  }
}
