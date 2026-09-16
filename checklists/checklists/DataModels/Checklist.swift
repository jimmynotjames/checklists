//
//  Checklist.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//

import Foundation
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// A single checklist. Top-level: unlike the Realm schema this replaces, there is no `Group`
/// object holding an ordered list of checklists — ordering lives on the checklist itself, in
/// `sortKey`, since a singleton `Group` is exactly the shape CloudKit cannot express.
/// See core-docs/persistence-design.md §Model / §CloudKit rules.
@Model
final class Checklist {
  var id: String = UUID().uuidString
  var name: String = ""
  var notes: String?

  /// User-defined display order, ascending. Not an index: reordering assigns a value *between*
  /// the two neighbours (see `SortKeyReorder`) so that moving one row rewrites one record
  /// rather than renumbering the whole list, which keeps cross-device merges small.
  var sortKey: Double = 0.0

  /// When an item here was last checked or unchecked — including by Reset, which unchecks them
  /// all. Renaming, re-noting, reordering, adding and deleting are *edits*, not updates, and
  /// leave this alone. `nil` means nobody has ever ticked anything on this list.
  var lastUpdated: Date?

  /// When this list last *became* complete, by any local route: the final tick, or the deletion of
  /// the one item still outstanding. Survives Reset — it records that a run finished rather than
  /// describing the list's current state, which is what `percentageComplete` is for.
  var lastCompleted: Date?

  /// Optional purely to satisfy CloudKit. **App code should never touch this** — use `items`,
  /// which is non-optional and correctly ordered.
  @Relationship(deleteRule: .cascade, inverse: \Item.checklist)
  var itemsStorage: [Item]?

  /// The checklist's items in display order. This is the canonical accessor for all app code.
  ///
  /// The underlying relationship is an *unordered* set as far as CloudKit is concerned, so the
  /// order has to be recomputed from `sortKey` on read rather than being a property of the
  /// stored array.
  var items: [Item] {
    (itemsStorage ?? []).sorted { lhs, rhs in
      lhs.sortKey == rhs.sortKey ? lhs.id < rhs.id : lhs.sortKey < rhs.sortKey
    }
  }

  var percentageComplete: CGFloat {
    let items = items
    guard !items.isEmpty else { return 0.0 }
    return CGFloat(items.count(where: { $0.status == .checked })) / CGFloat(items.count)
  }

  /// Every item checked, and there is at least one. An empty list is *not* complete, matching
  /// `percentageComplete`'s 0.0 for that case — so deleting the last outstanding item completes a
  /// list, while deleting all of them does not.
  ///
  /// Preferred over `percentageComplete == 1.0` at the call sites: it says what it means, and it
  /// is not a floating-point equality test.
  var isComplete: Bool {
    let items = items
    return !items.isEmpty && items.allSatisfy { $0.status == .checked }
  }

  init(id: String = UUID().uuidString, name: String = "", notes: String? = nil, sortKey: Double = 0.0) {
    self.id = id
    self.name = name
    self.notes = notes
    self.sortKey = sortKey
  }

  func uncheckAllItems() {
    for item in items {
      item.status = .unchecked
    }
  }

  // The two stamps below stay single-purpose rather than having completion imply an update,
  // because the rules behind them genuinely diverge: deleting the last outstanding item completes
  // a list, but deleting is an edit, so it must not move `lastUpdated`. A final tick calls both.
  //
  // `date` is injectable for the same reason `RatingPromptCoordinator` takes a `now` — it is the
  // only way to assert a stamp without sleeping.

  func recordUpdate(at date: Date = .now) {
    lastUpdated = date
  }

  func recordCompletion(at date: Date = .now) {
    lastCompleted = date
  }

  /// `@MainActor` because `UIDragItem` is: SwiftData models are not actor-isolated, so this would
  /// otherwise be a nonisolated method reaching into UIKit. Only ever called from a table view's
  /// drag delegate, which is already on the main actor.
  @MainActor
  func dragItems() -> [UIDragItem] {
    let itemProvider = NSItemProvider()
    let id = id
    itemProvider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .ownProcess) { completion in
      let data = id.data(using: .utf8)
      completion(data, nil)
      return nil
    }
    return [UIDragItem(itemProvider: itemProvider)]
  }
}
