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
      fatalError(error.description)
      // TODO: Try to some more elegant error handling here?
    }
  }()

  static func write(_ block: () -> Void) {
    do {
      try realm.write {
        block()
      }
    } catch let error as NSError {
      fatalError(error.description)
      // TODO: Try to some more elegant error handling here?
    }
  }
}

