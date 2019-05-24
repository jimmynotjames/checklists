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
  static func insertTestData() {
    let realm = DBManager.realm

    var checklists: [Checklist] = []

    var items = [Item(name: "task 1"), Item(name: "task 2", notes: "some notes for\ntask 2\nFOOBAR")]
    checklists.append(Checklist(name: "Checklist1 Name", notes: "Checklist1\nnotes", items: items))

    items = [Item(name: "task a"), Item(name: "task b")]
    checklists.append(Checklist(name: "Checklist 2 FOOBAR", items: items))

    DBManager.write {
      realm.add(checklists)
    }
  }

  static func printTestData() {
    let realm = DBManager.realm

    for checklist in realm.objects(Checklist.self) {
      print("Checklist Name: \(checklist.name)")
      print("Checklist Notes: \(String(describing: checklist.notes))")
      print("Items: \(checklist.items)")
    }
  }
}
