//
//  ChecklistsRealmObjects.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation
import RealmSwift

class Checklist: Object {
  @objc dynamic var id = NSUUID().uuidString
  @objc dynamic var name: String = ""
  @objc dynamic var notes: String?
  @objc dynamic var sortNumber: Double = 0.0
  @objc dynamic var lastModified: Date = Date()

  let items = List<Item>()

  convenience init(name: String, notes: String? = nil, sortNumber: Double? = nil, items: [Item]) {
    self.init()
    self.name = name
    self.notes = notes
    if let sortNumber = sortNumber {
      self.sortNumber = sortNumber
    }
    self.items.append(objectsIn: items)
  }

  static func calculateSortNumber(between checklist1: Checklist, and checklist2: Checklist) -> Double {
    return (checklist1.sortNumber + checklist2.sortNumber) / 2.0
  }

  static func calculateSortNumber(before checklist: Checklist) -> Double {
    return checklist.sortNumber - 1.0
  }

  static func calculateSortNumber(after checklist: Checklist) -> Double {
    return checklist.sortNumber + 1.0
  }

  // When list is empty
  static func startingSortNumber() -> Double {
    return 8.0
  }

  func remove(at index: Int) {
    guard index >= 0 && index < items.count else { assertionFailure(); return }
    DBManager.write {
      let item = items[index]
      items.remove(at: index)
      DBManager.realm.delete(item)
    }
  }

  func swapItemsAt(_ index1: Int, _  index2: Int) {
    guard index1 >= 0 && index1 < items.count else { assertionFailure(); return }
    guard index2 >= 0 && index2 < items.count else { assertionFailure(); return }
    guard index1 != index2 else { return }

    DBManager.write {
      items.swapAt(index1, index2)
    }
  }

  func moveItem(from fromIndex: Int, to toIndex: Int) {
    guard fromIndex >= 0 && fromIndex < items.count else { assertionFailure(); return }
    guard toIndex >= 0 && toIndex < items.count else { assertionFailure(); return }
    guard fromIndex != toIndex else { return }

    DBManager.write {
      items.move(from: fromIndex, to: toIndex)
    }
  }
}

/*
 TODO: I haven't figured out how to do this via the schema yet, but I want
 to constrain is so an Item is attached to only one Checklist.
 */
class Item: Object {

  enum Status: Int {
    case unchecked
    case checked

    static let defaultValue: Status = .unchecked
  }

  @objc dynamic var id = NSUUID().uuidString
  @objc dynamic var name: String = ""
  @objc dynamic var notes: String?
  @objc dynamic var statusRaw: Int = Status.defaultValue.rawValue

  var status: Status {
    get {
      return Status(rawValue: statusRaw) ?? Status.defaultValue
    }
    set {
      statusRaw = newValue.rawValue
    }
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
}

