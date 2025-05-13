//
//  DBManager.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation
import RealmSwift

class DBManager {
  static var realm: Realm = {
    do {
      return try Realm()
    } catch let error as NSError {
      AnalyticsManager.logRealmFailure(errorMessage: error.description)
      fatalError(error.description)
      // TODO: Try to some more elegant error handling here.
    }
  }()
  
  // For using in Previews and such.
  static func initializeDebugRealm() {
    realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "DebugRealm"))
  }

  static func write(_ block: () -> Void) {
    do {
      try realm.write {
        block()
      }
    } catch let error as NSError {
      AnalyticsManager.logRealmWriteFailure(errorMessage: error.description)
      fatalError(error.description)
      // TODO: Try to some more elegant error handling here.
    }
  }
  
  static func getGroup() -> Group {
    if let group = realm.objects(Group.self).first {
      return group
    } else {
      AnalyticsManager.logRealmFailure(errorMessage: "Group object not found in database.")
      fatalError("Group object not found in database.")
    }
  }

  static func resetAllChecklists() {
    let group = getGroup()
    for checklist in group.checklists {
      checklist.uncheckAllItems()
    }
  }

  static func cleanUpDeletedChecklists() {
    let group = getGroup()
    write {
      group.checklists.filter { $0.isDeleted }.forEach { checklist in
        realm.delete(checklist.items)
        realm.delete(checklist)
      }
    }
  }

  // For migrating from v1.0 to higher versions. Updating scheme from using sortNumber to using
  // the Group object to hold a ordered list. Group object is used as of v1.1.
  static func migrateDatabaseToUseGroupObjectIfNecessary() {
    if realm.objects(Group.self).isEmpty {
      let group = Group()
      write {
        realm.add(group)
        let checklists = realm.objects(Checklist.self).sorted(byKeyPath: "sortNumber")
        for checklist in checklists {
          group.checklists.append(checklist)
        }
      }
    }
  }

  // For app versions 1 and 1.1, I never set a schema version, so it has
  // been defaulting to 0. With version 1.1.1, let's set it to version 1.
  static func migrateToAppVersion1_1_1() {
    let config = Realm.Configuration(schemaVersion: 1, migrationBlock: nil)
    Realm.Configuration.defaultConfiguration = config
  }
}

// MARK: Debugging methods
extension DBManager {
  static func printChecklists() {
    print("-------------DEBUG: Printing all checklists...")
    let realm = self.realm

    for checklist in realm.objects(Checklist.self).sorted(byKeyPath: "sortNumber") {
      print("Checklist Name: \(checklist.name)")
      print("notes: \(String(describing: checklist.notes))")
      print("sortNumber: \(checklist.sortNumber)")
      print("Items: \(checklist.items)")
    }
    print("-------------COMPLETED printing all checklists...")
  }
  
  static func printRealmInstance(object: RealmSwift.Object) {
    if let realm = object.realm {
      print("\(object.objectSchema.className) belongs to Realm at: \(realm.configuration.fileURL?.absoluteString ?? "unknown")")
    } else {
      print("\(object.objectSchema.className) has a nil Realm instance.")
    }
  }
}
