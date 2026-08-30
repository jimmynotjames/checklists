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
      // Diagnostics first: this is the only record that survives into Release, and it outlives the
      // fatalError below. The domain/code/localizedDescription are logged public because they are
      // what makes a sysdiagnose actionable and are bounded to Realm's own failure text. The full
      // `description` is logged private because it serialises the entire userInfo dictionary,
      // which is not bounded and is not ours to promise is free of user content.
      os_log(
        "Realm could not be opened: %{public}@ %{public}ld %{public}@ | %@",
        log: AppLog.persistence,
        type: .fault,
        error.domain,
        error.code,
        error.localizedDescription,
        error.description
      )
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
      // See the note in `realm` above on the ordering and the public/private split.
      os_log(
        "Realm write transaction failed: %{public}@ %{public}ld %{public}@ | %@",
        log: AppLog.persistence,
        type: .fault,
        error.domain,
        error.code,
        error.localizedDescription,
        error.description
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
