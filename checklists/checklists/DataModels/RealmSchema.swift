//
//  ChecklistsRealmObjects.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation
import RealmSwift

class Item: Object {

  enum Status: Int {
    case unchecked
    case checked

    static let defaultValue: Status = .unchecked
  }

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

class Checklist: Object {
  @objc dynamic var name: String = ""
  @objc dynamic var notes: String?
  @objc dynamic var sortNumber: Int = 0 // Not performant, but for small dataset, this should be fine, and better for debugging readability.
  @objc dynamic var lastModified: Date = Date()

  let items = List<Item>()

  convenience init(name: String, notes: String? = nil, sortNumber: Int? = nil, items: [Item]) {
    self.init()
    self.name = name
    self.notes = notes
    if let sortNumber = sortNumber {
      self.sortNumber = sortNumber
    }
    self.items.append(objectsIn: items)
  }
}
