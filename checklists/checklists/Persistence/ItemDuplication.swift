//
//  ItemDuplication.swift
//  checklists
//

import Foundation
import SwiftData

extension ModelContext {
  /// Copies `source` and places the copy directly after it within the same checklist.
  ///
  /// Unlike `duplicate(checklist:among:)`, the name is carried over unchanged — there is no
  /// "copy" suffix for an item, and no collision to disambiguate.
  @discardableResult
  func duplicate(item source: Item, in checklist: Checklist) throws -> Item {
    // Status is deliberately not carried over — a copy has not been done yet.
    let copy = Item(name: source.name, notes: source.notes)
    let items = checklist.items
    let index = items.firstIndex { $0 === source }.map { $0 + 1 } ?? items.count
    // `insert(item:at:in:)` assigns the sort key, links the relationship, and saves.
    try insert(item: copy, at: index, in: checklist)
    return copy
  }
}
