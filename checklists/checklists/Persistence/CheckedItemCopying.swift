//
//  CheckedItemCopying.swift
//  checklists
//

import Foundation
import SwiftData

extension Checklist {
  /// The items a copy would carry: ticked, and not the scratch row the detail screen seeds and
  /// trims.
  ///
  /// Shared by the operations below, by Delete Checked Items, and by the overflow-menu entries that
  /// offer them, so a tap on an entry acts only when there is something to act on, and shows the
  /// "No checked items." notice otherwise — including when the only ticked row is a blank one.
  var checkedItems: [Item] {
    items.filter { $0.status == .checked && !$0.isBlank }
  }
}

extension ModelContext {
  /// Copies `source`'s checked items into a brand-new checklist at the top of the user's ordering.
  ///
  /// No history stamps on the copy (persistence-design.md §Duplication), and none on `source`:
  /// copying from a list is not a run of it.
  ///
  /// - Parameter siblings: every checklist in display order, **excluding** the new one.
  /// - Returns: the new checklist, inserted and saved.
  @discardableResult
  func copyCheckedItems(
    of source: Checklist,
    intoChecklistNamed name: String,
    among siblings: [Checklist]
  ) throws -> Checklist {
    let destination = Checklist(name: name)
    insert(destination)

    // Keys are re-issued rather than copied, as `duplicate(checklist:among:)` does: `checkedItems`
    // is already in display order, so spacing them afresh preserves it and leaves the new list
    // evenly spaced room to reorder.
    var sortKey = SortKeyReorder.step
    var copies: [Item] = []
    for item in source.checkedItems {
      copies.append(insertCopy(of: item, sortKey: sortKey, into: destination))
      sortKey += SortKeyReorder.step
    }

    do {
      // Top, not beside the source — deliberately unlike `duplicate(checklist:among:)`. A copy *of*
      // a list belongs next to its original; this is a new list derived from a subset, a sibling of
      // nothing, and it carries a generic name the user has to find in order to rename.
      // `ChecklistsView.addChecklist` puts a new checklist here for the same reason.
      try placeAndSave(destination, at: 0, among: siblings, restoringSortKeysOf: siblings) {
        try saveChanges(operation: .checklistEdit)
      }
    } catch {
      // `placeAndSave` puts the siblings' keys back; the half-built destination is this method's to
      // undo, item by item, for the reasons `duplicate(checklist:among:)` sets out.
      for copy in copies {
        delete(copy)
      }
      delete(destination)
      throw error
    }
    return destination
  }

  /// Appends `source`'s checked items to the end of an existing `destination`.
  ///
  /// `destination`'s `lastUpdated` is left alone: adding an item is an edit, and `insert(item:at:
  /// in:)` does not stamp it either. `lastCompleted` is untouched for the same reason — the arriving
  /// items are unchecked, so they can only ever make a list less complete.
  ///
  /// - Returns: the copies, inserted and saved.
  @discardableResult
  func copyCheckedItems(of source: Checklist, into destination: Checklist) throws -> [Item] {
    // Appended rather than inserted at the top: this is how items normally arrive — the add-item
    // footer appends — and dropping foreign unchecked rows above a list someone is mid-run on
    // would disturb an order that usually means sequence. Stepping up from the last key needs no
    // renormalizing, which is why this does not go through `place`.
    var sortKey = (destination.items.last?.sortKey ?? 0.0) + SortKeyReorder.step
    var copies: [Item] = []
    for item in source.checkedItems {
      copies.append(insertCopy(of: item, sortKey: sortKey, into: destination))
      sortKey += SortKeyReorder.step
    }

    do {
      // One save for the whole batch, not one per item; `.itemEdit` because that is what arriving
      // items are, matching `insert(item:at:in:)`.
      try saveChanges(operation: .itemEdit)
    } catch {
      // Left staged, the copies would render in a list they were never written to. Unlinked first,
      // as `insert(item:at:in:)` does, so the list's items drop them now rather than at the next save.
      for copy in copies {
        copy.checklist = nil
        delete(copy)
      }
      throw error
    }
    return copies
  }

  /// `copyCheckedItems(of:intoChecklistNamed:among:)`, then removes the originals from `source`.
  ///
  /// The removal is a second save, after the copy has landed: if it fails, the items sit in both
  /// lists rather than in neither.
  ///
  /// - Returns: the new checklist, inserted and saved.
  @discardableResult
  func moveCheckedItems(
    of source: Checklist,
    intoChecklistNamed name: String,
    among siblings: [Checklist]
  ) throws -> Checklist {
    let originals = source.checkedItems
    let destination = try copyCheckedItems(of: source, intoChecklistNamed: name, among: siblings)
    deleteItems(originals, from: source)
    return destination
  }

  /// `copyCheckedItems(of:into:)`, then removes the originals from `source`, in the same order as
  /// `moveCheckedItems(of:intoChecklistNamed:among:)` for the same reason.
  ///
  /// - Returns: the copies, inserted and saved.
  @discardableResult
  func moveCheckedItems(of source: Checklist, into destination: Checklist) throws -> [Item] {
    let originals = source.checkedItems
    let copies = try copyCheckedItems(of: source, into: destination)
    deleteItems(originals, from: source)
    return copies
  }

  /// Deletes `items` from `checklist` in one save: the second half of a move, and the whole of the
  /// detail screen's Delete Checked Items.
  ///
  /// Unlinked before deleting, as the copy paths' failure branches do, so `checklist.items` drops
  /// them now rather than at the next save. Through `saveDeletion` like any other item deletion.
  func deleteItems(_ items: [Item], from checklist: Checklist) {
    let wasComplete = checklist.isComplete
    for item in items {
      item.checklist = nil
      delete(item)
    }
    saveDeletion(from: checklist, wasComplete: wasComplete)
  }

  /// Name and notes only. **Copies arrive unchecked**, as they do on both existing copy paths: a
  /// fresh list to run is the point.
  private func insertCopy(of item: Item, sortKey: Double, into destination: Checklist) -> Item {
    let copy = Item(name: item.name, notes: item.notes, sortKey: sortKey)
    insert(copy)
    // Child side only; see `Reordering`.
    copy.checklist = destination
    return copy
  }
}
