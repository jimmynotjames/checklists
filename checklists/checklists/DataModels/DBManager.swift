//
//  DBManager.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//

import Foundation
import RealmSwift

class DBManager {
  static var realm: Realm = {
    do {
      return try Realm()
    } catch let error as NSError {
      // Diagnostics first: this is the only record that survives into Release, and it outlives the
      // fatalError below. The domain/code/localizedDescription are logged public because they are
      // what makes a sysdiagnose actionable and are bounded to Realm's own failure text. The full
      // `description` is logged private because it serialises the entire userInfo dictionary,
      // which is not bounded and is not ours to promise is free of user content.
      AppLog.persistence.fault(
        "Realm could not be opened: \(error.domain, privacy: .public) \(error.code, privacy: .public) \(error.localizedDescription, privacy: .public) | \(error.description, privacy: .private)"
      )
      AnalyticsManager.logRealmFailure(errorMessage: error.description)
      fatalError(error.description)
      // TODO: Try to some more elegant error handling here.
    }
  }()

  /**
   Runs `block` in a write transaction and stamps `checklist.lastModified` in that same
   transaction, so a checklist's timestamp can never drift out of sync with the edit that caused it.

   Pass `nil` to skip the stamp. That is not a convenience — it is how callers express
   "this write touches placeholder scaffolding, not user content", which is the distinction
   `lastModified` is meant to capture. See `Item.isEmpty`.

   Not for deleting the checklist itself: the stamp runs *after* `block`, so a block that deletes
   `checklist` would leave this writing to an invalidated object.
   */
  static func write(touching checklist: Checklist?, _ block: () -> Void) {
    write {
      block()
      checklist?.lastModified = Date()
    }
  }

  static func write(_ block: () -> Void) {
    do {
      try realm.write {
        block()
      }
    } catch let error as NSError {
      // See the note in `realm` above on the ordering and the public/private split.
      AppLog.persistence.fault(
        "Realm write transaction failed: \(error.domain, privacy: .public) \(error.code, privacy: .public) \(error.localizedDescription, privacy: .public) | \(error.description, privacy: .private)"
      )
      AnalyticsManager.logRealmWriteFailure(errorMessage: error.description)
      fatalError(error.description)
      // TODO: Try to some more elegant error handling here.
    }
  }
}

// MARK: Debugging methods

extension DBManager {
  static func printChecklists() {
    print("-------------DEBUG: Printing all checklists...")
    let realm = realm

    for checklist in realm.objects(Checklist.self).sorted(byKeyPath: "sortNumber") {
      print("Checklist Name: \(checklist.name)")
      print("notes: \(String(describing: checklist.notes))")
      print("sortNumber: \(checklist.sortNumber)")
      print("lastModified: \(checklist.lastModified)")
      print("Items: \(checklist.items)")
    }
    print("-------------COMPLETED printing all checklists...")
  }
}
