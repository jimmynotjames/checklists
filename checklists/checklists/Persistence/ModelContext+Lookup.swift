//
//  ModelContext+Lookup.swift
//  checklists
//

import Foundation
import SwiftData

extension ModelContext {
  /// All checklists in display order.
  ///
  /// `id` breaks ties so the order is total and stable. Two records can genuinely share a
  /// `sortKey` under sync — CloudKit cannot enforce uniqueness, so two devices editing
  /// while apart can both land on the same key — and a table view whose row order flickers between
  /// reloads is worse than an arbitrary but fixed choice.
  func fetchChecklistsSorted() throws -> [Checklist] {
    try fetch(
      FetchDescriptor<Checklist>(
        sortBy: [SortDescriptor(\.sortKey), SortDescriptor(\.id)]
      )
    )
  }

  /// Resolves a checklist by its app-assigned `id`.
  ///
  /// Navigation routes (`AppRoute`, `SheetRoute`) carry this `id` rather than a
  /// `PersistentIdentifier`, so a reference survives the record being re-created by a sync merge.
  /// `nil` means the record is gone — deleted here, or deleted on another device.
  func checklist(id: String) -> Checklist? {
    var descriptor = FetchDescriptor<Checklist>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return (try? fetch(descriptor))?.first
  }

  func item(id: String) -> Item? {
    var descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return (try? fetch(descriptor))?.first
  }
}
