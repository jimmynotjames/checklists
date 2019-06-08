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

    checklists.append(Checklist(name: "Day Drinking",
                                sortNumber: 1.0,
                                items: [Item(name: "task 1"),
                                        Item(name: "item a"),
                                        Item(name: "item b")]))

    checklists.append(Checklist(name: "Dinner Volunteer Packing List",
                                notes: "For dinner volunteering\nline 2\nline 3",
                                sortNumber: 2.0,
                                items: [Item(name: "task 1"),
                                        Item(name: "task 2", notes: "some notes for\ntask 2\nFOOBAR")]))

    checklists.append(Checklist(name: "Nightlife",
                                sortNumber: 3.0,
                                items: [Item(name: "item 1"),
                                        Item(name: "item 2"),
                                        Item(name: "item 3")]))

    checklists.append(Checklist(name: "Purse Transfer Essentials",
                                sortNumber: 4.0,
                                items: [Item(name: "item a"),
                                        Item(name: "item b")]))

    DBManager.write {
      realm.add(checklists)
    }
  }
}
