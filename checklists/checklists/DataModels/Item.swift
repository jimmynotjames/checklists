//
//  Item.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//

import Foundation
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// A single row within a `Checklist`.
@Model
final class Item {
  enum Status: Int {
    case unchecked
    case checked

    nonisolated static let defaultValue: Status = .unchecked
  }

  var id: String = UUID().uuidString
  var name: String = ""
  var notes: String?

  /// Stored as its raw `Int` rather than as the enum so it stays filterable and sortable in a
  /// `#Predicate`, and so it is legible in the CloudKit dashboard.
  var statusRaw: Int = Status.defaultValue.rawValue

  /// User-defined display order within the parent checklist, ascending. See `Checklist.sortKey`.
  var sortKey: Double = 0.0

  /// The inverse of `Checklist.itemsStorage`. Optional because CloudKit requires every
  /// relationship to be optional, and because an item briefly has no parent while being created.
  var checklist: Checklist?

  var status: Status {
    get {
      Status(rawValue: statusRaw) ?? Status.defaultValue
    }
    set {
      statusRaw = newValue.rawValue
    }
  }

  init(id: String = UUID().uuidString, name: String = "", notes: String? = nil, sortKey: Double = 0.0) {
    self.id = id
    self.name = name
    self.notes = notes
    self.sortKey = sortKey
  }

  func toggleStatus() {
    switch status {
    case .unchecked: status = .checked
    case .checked: status = .unchecked
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
