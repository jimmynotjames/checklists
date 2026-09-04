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

/**
 A single checklist. Top-level: unlike the Realm schema this replaces, there is no `Group`
 object holding an ordered list of checklists.

 `Group` existed only to give checklists an arbitrary user-defined order, and it was a
 singleton — exactly the shape CloudKit cannot express. CloudKit enforces no uniqueness
 constraint, so two devices that each created their "one" `Group` before their first sync would
 end up with two of them and no principled way to pick a winner. Ordering therefore lives on the
 checklist itself, in `sortKey`.

 CloudKit constraints reflected here (see `core-docs/persistence-design.md`):
 - no `@Attribute(.unique)` anywhere — `id` is a plain attribute that happens to hold a UUID
 - every non-optional attribute has a default value
 - the to-many relationship is optional, because CloudKit syncs a record graph in pieces and a
   parent can legitimately arrive before its children
 */
@Model
final class Checklist {
  var id: String = UUID().uuidString
  var name: String = ""
  var notes: String?

  /// User-defined display order, ascending. Not an index: reordering assigns a value *between*
  /// the two neighbours (see `SortKeyReorder`) so that moving one row rewrites one record
  /// rather than renumbering the whole list, which keeps cross-device merges small.
  var sortKey: Double = 0.0

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
