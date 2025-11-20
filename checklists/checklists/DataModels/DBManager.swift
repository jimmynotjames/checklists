//
//  DBManager.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation
import RealmSwift

/*
 Thin wrapper around Realm database operations to

 Features:
 - Initializes Realm instance.
 - Wraps realm write operations to handle errors.
 - Conducts database migrations.

 Remaining Tasks:
 TODO: Implement better migration and remove certain fields, like sortNumber.
 TODO: Add to migration to add lastModified and lastCompleted fields to Checklist.
 */

class DBManager {
  static func getRealm() -> Realm {
    do {
      return try Realm()
    } catch let error as NSError {
      AnalyticsManager.logRealmFailure(errorMessage: error.description)
      fatalError(error.description)
      // TODO: Try to some more elegant error handling here.
    }
  }

  static func write(_ block: (Realm) -> Void) {
    let realm = getRealm()
    do {
      try realm.write {
        block(realm)
      }
    } catch let error as NSError {
      AnalyticsManager.logRealmFailure(errorMessage: error.description)
      fatalError(error.description)
      // TODO: Try to some more elegant error handling here.
    }
  }

  static func getGroup() -> Group {
    let realm = getRealm()
    if let group = realm.objects(Group.self).first {
      return group
    } else {
      AnalyticsManager.logRealmFailure(errorMessage: "Group object not found in database.")
      let group = Group()
      write { realm in
        realm.add(group)
      }
      return group
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
    write { realm in
      group.checklists.filter { $0.isDeleted }.forEach { checklist in
        realm.delete(checklist.items)
        realm.delete(checklist)
      }
    }
  }

  // TODO: My migration will eventually remove sortNumbers. Soooo, by the time this runs, I may not have sortNumber. How would I make this work? Maybe I leave the sortNumbers in for now? But this is from v1.1 onwards. This bug will only affect those moving from v1 to v1.1.1. I feel like... it's been several years? Who hasn't updated their app?????
  // Only to be called during app launch.
  // For migrating from v1.0 to higher versions. Updating scheme from using sortNumber to using
  // the Group object to hold a ordered list. Group object is used as of v1.1.
  static func migrateDatabaseToUseGroupObjectIfNecessary() {
    write { realm in
      if realm.objects(Group.self).isEmpty {
        let group = Group()
        realm.add(group)
        let checklists = realm.objects(Checklist.self).sorted(byKeyPath: "sortNumber")
        for checklist in checklists {
          group.checklists.append(checklist)
        }
      }
    }
  }

  // TODO: Did I have the `id` field for v1.1? Now it's `_id` and possibly a UInt64 instead of UUID/String. May need migration for that?
  /* TODO: Other possible migrations I may have to do:
   Thread 1: Fatal error: Error Domain=io.realm Code=10 "Migration is required due to the following errors:
   - Property 'Checklist.id' has been removed.
   - Property 'Checklist._id' has been added.
   - Primary Key for class 'Checklist' has been added.
   - Property 'Group.id' has been removed.
   - Property 'Group._id' has been added.
   - Primary Key for class 'Group' has been added.
   - Property 'Item.id' has been removed.
   - Property 'Item.statusRaw' has been removed.
   - Property 'Item._id' has been added.
   - Property 'Item.isChecked'
   */

  // With version 1.1.1, setting schema version to version 1.
  // For app versions 1 and 1.1, I never set a schema version, so it's been defaulting to 0.
  static func migrateToAppVersion1_1_1() {
    let config = Realm.Configuration(
      schemaVersion: 1,
      migrationBlock: { migration, oldSchemaVersion in
        if oldSchemaVersion < 1 {
          // Migrate from Item.Status:Int/.unchecked=0,checked=1 to isChecked:Bool/false,true
          migration.enumerateObjects(ofType: Item.className()) { oldObject, newObject in
            let rawStatus = oldObject?["statusRaw"] as? Int ?? 0
            newObject?["isChecked"] = (rawStatus == 1)
          }
          // Migrate Checklist.notes from Optional to non-Optional with default empty string
          migration.enumerateObjects(ofType: Checklist.className()) { oldObject, newObject in
            let oldNotes = oldObject?["notes"] as? String
            if oldNotes == nil {
              newObject?["notes"] = ""
            }
          }
          // Migrate Item.notes from Optional to non-Optional with default empty string
          migration.enumerateObjects(ofType: Item.className()) { oldObject, newObject in
            let oldNotes = oldObject?["notes"] as? String
            if oldNotes == nil {
              newObject?["notes"] = ""
            }
          }
        }
      }
    )
    Realm.Configuration.defaultConfiguration = config
  }
}

// MARK: Debugging methods
extension DBManager {
  static func printChecklists() {
    print("-------------DEBUG: Printing all checklists...")
    for checklist in getGroup().checklists {
      print("Checklist Name: \(checklist.name)")
      print("notes: \(String(describing: checklist.notes))")
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
