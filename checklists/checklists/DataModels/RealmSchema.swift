//
//  ChecklistsRealmObjects.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation
import UIKit
import MobileCoreServices
import RealmSwift

/*
 Current implementation is for this to be a singleton-style object,
 using the List to preserve arbitrary ordering of the Checklists.
 Perhaps in the future, some sort of tagging or folder structure
 could be implemented, which would result in more Group objects.

 Added in app version 1.1.
 */
class Group: Object, Identifiable {
  @Persisted var id = NSUUID().uuidString

  @Persisted var checklists = List<Checklist>()

  func displayedChecklists() -> Results<Checklist> {
    return checklists.where { !$0.isDeleted }
  }

  func moveChecklist(from fromIndex: Int, to toIndex: Int) {
    guard fromIndex >= 0 && fromIndex < checklists.count else { assertionFailure(); return }
    guard toIndex >= 0 && toIndex < checklists.count else { assertionFailure(); return }
    guard fromIndex != toIndex else { return }

    DBManager.write {
      checklists.move(from: fromIndex, to: toIndex)
    }
  }
  
  func delete(checklist: Checklist) {
    // After implementing with SwiftUI (iOS 18), we need to retrieve the checklist object again or else we get
    // an error regarding using the wrong Realm instance. Possibly due to copying the item through itemToDelete.
    let realm = DBManager.realm
    if let checklist = realm.objects(Checklist.self).filter("id == %@", checklist.id).first {
      DBManager.write {
        realm.delete(checklist.items)
        realm.delete(checklist)
      }
    }
  }

  func shallowDelete(checklist: Checklist) {
    DBManager.write {
      checklist.thaw()?.isDeleted = true
    }
  }

  func undoDeletion(checklist: Checklist) {
    DBManager.write {
      checklist.thaw()?.isDeleted = false
    }
  }
}


class Checklist: Object, Identifiable {
  @Persisted var id = NSUUID().uuidString
  @Persisted var name: String = ""
  @Persisted var notes: String?
  @Persisted var sortNumber: Double = 0.0 // Obsolete as of app version 1.1.0.
  @Persisted var lastModified: Date = Date()
  @Persisted var isDeleted = false // Added in app version 1.1.1.

  @Persisted var items = RealmSwift.List<Item>()

  var percentageComplete: CGFloat {
    get {
      guard items.count > 0 else { return 0.0 }
      return CGFloat(items.filter({ $0.status == .checked }).count) / CGFloat(items.count)
    }
  }

  convenience init(name: String, notes: String? = nil, sortNumber: Double? = nil, items: [Item]) {
    self.init()
    self.name = name
    self.notes = notes
    if let sortNumber = sortNumber {
      self.sortNumber = sortNumber
    }
    self.items.append(objectsIn: items)
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

  func uncheckAllItems() {
    DBManager.write {
      items.forEach { item in
        item.status = .unchecked
      }
    }
  }

  func dragItems() -> [UIDragItem] {
    let itemProvider = NSItemProvider()
    itemProvider.registerDataRepresentation(forTypeIdentifier: kUTTypePlainText as String, visibility: .ownProcess) { completion in
      let data = self.id.data(using: .utf8)
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

    static let defaultValue: Status = .unchecked
  }

  @Persisted var id = NSUUID().uuidString
  @Persisted var name: String = ""
  @Persisted var notes: String?
  @Persisted var statusRaw: Int = Status.defaultValue.rawValue

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

  func dragItems() -> [UIDragItem] {
    let itemProvider = NSItemProvider()
    itemProvider.registerDataRepresentation(forTypeIdentifier: kUTTypePlainText as String, visibility: .ownProcess) { completion in
      let data = self.id.data(using: .utf8)
      completion(data, nil)
      return nil
    }
    return [UIDragItem(itemProvider: itemProvider)]
  }
}

