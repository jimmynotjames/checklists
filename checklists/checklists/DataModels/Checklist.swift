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

  /// Every real item checked, and there is at least one. An empty list is *not* complete, matching
  /// `percentageComplete`'s 0.0 for that case — so deleting the last outstanding item completes a
  /// list, while deleting all of them does not.
  ///
  /// Blank rows are excluded (`Item.isBlank`). Counting them would mean a list stopped being
  /// complete the moment the add button left a scratch row behind, and started again when the row
  /// was trimmed on close — which would restamp `lastCompleted` for someone who only opened the
  /// screen and backed out. `percentageComplete` still counts them, so the ring can read below 100%
  /// on a list this considers complete; the ring describes what is on screen, this describes a run.
  ///
  /// Preferred over `percentageComplete == 1.0` at the call sites: it says what it means, and it
  /// is not a floating-point equality test.
  var isComplete: Bool {
    let realItems = items.filter { !$0.isBlank }
    return !realItems.isEmpty && realItems.allSatisfy { $0.status == .checked }
  }

  init(id: String = UUID().uuidString, name: String = "", notes: String? = nil, sortKey: Double = 0.0) {
    self.id = id
    self.name = name
    self.notes = notes
    self.sortKey = sortKey
  }

  /// Unchecks everything, reporting whether anything was actually checked.
  ///
  /// The return value is what keeps Reset from stamping `lastUpdated` on a list that had nothing
  /// ticked — "Updated" has to mean something changed, or one Reset All would date every list in
  /// the app.
  @discardableResult
  func uncheckAllItems() -> Bool {
    var didUncheck = false
    for item in items where item.status == .checked {
      item.status = .unchecked
      didUncheck = true
    }
    return didUncheck
  }

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
