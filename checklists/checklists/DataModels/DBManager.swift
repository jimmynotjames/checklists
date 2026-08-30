//
//  DBManager.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation
import os
import RealmSwift

class DBManager {
  static var realm: Realm = {
    do {
      return try Realm()
    } catch let error as NSError {
      // Diagnostics first: this is the only record that survives into Release, and it reaches the
      // unified log synchronously, so it outlives the fatalError below. `%{public}@` is
      // deliberate — a Realm error description is a file path and an error code, not user
      // content, and it is useless in a sysdiagnose if redacted to <private>.
      os_log("Realm could not be opened: %{public}@", log: AppLog.persistence, type: .fault, error.description)
      AnalyticsManager.logRealmFailure(errorMessage: error.description)
      fatalError(error.description)
      // TODO: Try to some more elegant error handling here.
    }
  }()

  static func write(_ block: () -> Void) {
    do {
      try realm.write {
        block()
      }
    } catch let error as NSError {
      // See the note in `realm` above on why this logs before the analytics call and why the
      // error description is logged as public.
      os_log("Realm write transaction failed: %{public}@", log: AppLog.persistence, type: .fault, error.description)
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
    let realm = self.realm

    for checklist in realm.objects(Checklist.self).sorted(byKeyPath: "sortNumber") {
      print("Checklist Name: \(checklist.name)")
      print("notes: \(String(describing: checklist.notes))")
      print("sortNumber: \(checklist.sortNumber)")
      print("Items: \(checklist.items)")
    }
    print("-------------COMPLETED printing all checklists...")
  }
}
