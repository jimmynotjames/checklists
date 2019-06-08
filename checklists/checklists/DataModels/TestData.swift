//
//  TestData.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation
import RealmSwift

class TestData {
  static func clearDatabase() {
    print("DEBUG: Clearing database...")
    let realm = DBManager.realm
    DBManager.write {
      realm.deleteAll()
    }
  }

  static func insertTestData() {
    print("DEBUG: Inserting test data...")
    let realm = DBManager.realm

    var checklists: [Checklist] = []

    checklists.append(Checklist(name: "Checklist1 Name",
                                notes: "Checklist1\nnotes",
                                items: [Item(name: "task 1"),
                                        Item(name: "task 2", notes: "some notes for\ntask 2\nFOOBAR")]))

    checklists.append(Checklist(name: "Checklist 2 FOOBAR",
                                items: [Item(name: "task a"),
                                        Item(name: "task b")]))

    DBManager.write {
      realm.add(checklists)
    }
  }
}
