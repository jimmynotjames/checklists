//
//  RealmSchema.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//

import Foundation
import RealmSwift
import UIKit
import UniformTypeIdentifiers

/**
 Current implementation is for this to be a singleton-style object,
 using the List to preserve arbitrary ordering of the Checklists.
 Perhaps in the future, some sort of tagging or folder structure
 could be implemented, which would result in more Group objects.
 */
class Group: Object {
  @objc dynamic var id = NSUUID().uuidString

  let checklists = List<Checklist>()

  override nonisolated init() {
    super.init()
  }

  func moveChecklist(from fromIndex: Int, to toIndex: Int) {
    guard fromIndex >= 0, fromIndex < checklists.count else { assertionFailure(); return }
    guard toIndex >= 0, toIndex < checklists.count else { assertionFailure(); return }
    guard fromIndex != toIndex else { return }

    DBManager.write {
      checklists.move(from: fromIndex, to: toIndex)
    }
  }
}

class Checklist: Object {
  @objc dynamic var id = NSUUID().uuidString
  @objc dynamic var name: String = ""
  @objc dynamic var notes: String?
  @objc dynamic var sortNumber: Double = 0.0
  @objc dynamic var lastModified: Date = .init()

  let items = List<Item>()

  var percentageComplete: CGFloat {
    guard !items.isEmpty else { return 0.0 }
    return CGFloat(items.count(where: { $0.status == .checked })) / CGFloat(items.count)
  }

  override nonisolated init() {
    super.init()
  }

  convenience init(name: String, notes: String? = nil, sortNumber: Double? = nil, items: [Item]) {
    self.init()
    self.name = name
    self.notes = notes
    if let sortNumber {
      self.sortNumber = sortNumber
    }
    self.items.append(objectsIn: items)
  }

  func remove(at index: Int) {
    guard index >= 0, index < items.count else { assertionFailure(); return }
    DBManager.write {
      let item = items[index]
      items.remove(at: index)
      DBManager.realm.delete(item)
    }
  }

  func swapItemsAt(_ index1: Int, _ index2: Int) {
    guard index1 >= 0, index1 < items.count else { assertionFailure(); return }
    guard index2 >= 0, index2 < items.count else { assertionFailure(); return }
    guard index1 != index2 else { return }

    DBManager.write {
      items.swapAt(index1, index2)
    }
  }

  func moveItem(from fromIndex: Int, to toIndex: Int) {
    guard fromIndex >= 0, fromIndex < items.count else { assertionFailure(); return }
    guard toIndex >= 0, toIndex < items.count else { assertionFailure(); return }
    guard fromIndex != toIndex else { return }

    DBManager.write {
      items.move(from: fromIndex, to: toIndex)
    }
  }

  func uncheckAllItems() {
    DBManager.write {
      for item in items {
        item.status = .unchecked
      }
    }
  }

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

class Item: Object {
  enum Status: Int {
    case unchecked
    case checked

    nonisolated static let defaultValue: Status = .unchecked
  }

  @objc dynamic var id = NSUUID().uuidString
  @objc dynamic var name: String = ""
  @objc dynamic var notes: String?
  @objc dynamic var statusRaw: Int = Status.defaultValue.rawValue

  var status: Status {
    get {
      Status(rawValue: statusRaw) ?? Status.defaultValue
    }
    set {
      statusRaw = newValue.rawValue
    }
  }

  override nonisolated init() {
    super.init()
  }

  convenience init(name: String, notes: String? = nil) {
    self.init()
    self.name = name
    self.notes = notes
  }

  func toggleStatus() {
    switch status {
    case .unchecked: status = .checked
    case .checked: status = .unchecked
    }
  }

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
