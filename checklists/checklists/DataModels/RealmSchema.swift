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

  func calculateSortNumber(between checklist1: Checklist, and checklist2: Checklist) -> Double {
    return (checklist1.sortNumber + checklist2.sortNumber) / 2.0
  }

  func calculateSortNumber(before checklist: Checklist) -> Double {
    return checklist.sortNumber - 1.0
  }

  func calculateSortNumber(after checklist: Checklist) -> Double {
    return checklist.sortNumber + 1.0
  }
}

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
}

