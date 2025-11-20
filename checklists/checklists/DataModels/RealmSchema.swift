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
final class Group: Object, ObjectKeyIdentifiable {
  @Persisted(primaryKey: true) var _id: ObjectId

  @Persisted var checklists = List<Checklist>()

  func displayedChecklists() -> Results<Checklist> {
    return checklists.where { !$0.isDeleted }
  }

  func moveChecklist(from fromIndex: Int, to toIndex: Int) {
    guard fromIndex >= 0 && fromIndex < checklists.count else { assertionFailure(); return }
    guard toIndex >= 0 && toIndex < checklists.count else { assertionFailure(); return }
    guard fromIndex != toIndex else { return }

    DBManager.write { _ in
      checklists.move(from: fromIndex, to: toIndex)
    }
  }
  
  func delete(checklist: Checklist) {
    // After implementing with SwiftUI (iOS 18), we need to retrieve the checklist object again or else we get
    // an error regarding using the wrong Realm instance. Possibly due to copying the item through itemToDelete.
    let realm = DBManager.getRealm()
    if let checklist = realm.objects(Checklist.self).filter("id == %@", checklist.id).first {
      DBManager.write { realm in
        realm.delete(checklist.items)
        realm.delete(checklist)
      }
    }
  }

  func shallowDelete(checklist: Checklist) {
    DBManager.write { _ in
      checklist.thaw()?.isDeleted = true
    }
  }

  func undoDeletion(checklist: Checklist) {
    DBManager.write { _ in
      checklist.thaw()?.isDeleted = false
    }
  }
}

final class Checklist: Object, ObjectKeyIdentifiable {
  @Persisted(primaryKey: true) var _id: ObjectId
  @Persisted var name: String = ""
  @Persisted var notes: String?
  @Persisted var sortNumber: Double = 0.0 // Obsolete as of app version 1.1.0.
  @Persisted var lastModified: Date = Date()
  @Persisted var isDeleted = false // Added in app version 1.1.1.

  @Persisted var items = RealmSwift.List<Item>()

  var percentageComplete: CGFloat {
    get {
      guard items.count > 0 else { return 0.0 }
      return CGFloat(items.filter({ $0.isChecked == true }).count) / CGFloat(items.count)
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
    DBManager.write { realm in
      let item = items[index]
      items.remove(at: index)
      realm.delete(item)
    }
  }

  func swapItemsAt(_ index1: Int, _  index2: Int) {
    guard index1 >= 0 && index1 < items.count else { assertionFailure(); return }
    guard index2 >= 0 && index2 < items.count else { assertionFailure(); return }
    guard index1 != index2 else { return }

    DBManager.write { _ in
      items.swapAt(index1, index2)
    }
  }

  func moveItem(from fromIndex: Int, to toIndex: Int) {
    guard fromIndex >= 0 && fromIndex < items.count else { assertionFailure(); return }
    guard toIndex >= 0 && toIndex < items.count else { assertionFailure(); return }
    guard fromIndex != toIndex else { return }

    DBManager.write { _ in 
      items.move(from: fromIndex, to: toIndex)
    }
  }

  func uncheckAllItems() {
    DBManager.write { _ in
      items.forEach { item in
        item.isChecked = false
      }
    }
  }

  // TODO: Remove this eventually, when we remove the UIKit view controllers.
  func dragItems() -> [UIDragItem] {
    let itemProvider = NSItemProvider()
    itemProvider.registerDataRepresentation(forTypeIdentifier: kUTTypePlainText as String, visibility: .ownProcess) { completion in
      let idString = self._id.stringValue
      let data = idString.data(using: String.Encoding.utf8)
      completion(data, nil)
      return nil
    }
    return [UIDragItem(itemProvider: itemProvider)]
  }
}

final class Item: Object, ObjectKeyIdentifiable {

  @Persisted(primaryKey: true) var _id: ObjectId
  @Persisted var name: String = ""
  @Persisted var notes: String?

  // TODO: Will need to consider migration block from old version to new version
  // @Persisted var statusRaw: Int = Status.defaultValue.rawValue
  @Persisted var isChecked: Bool = false

  convenience init(name: String, notes: String? = nil) {
    self.init()
    self.name = name
    self.notes = notes
  }

  func toggleStatus() {
    isChecked = !isChecked
  }

  func dragItems() -> [UIDragItem] {
    let itemProvider = NSItemProvider()
    itemProvider.registerDataRepresentation(forTypeIdentifier: kUTTypePlainText as String, visibility: .ownProcess) { completion in
      let idString = self._id.stringValue
      let data = idString.data(using: String.Encoding.utf8)
      completion(data, nil)
      return nil
    }
    return [UIDragItem(itemProvider: itemProvider)]
  }
}

