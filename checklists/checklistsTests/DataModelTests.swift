//
//  DataModelTests.swift
//  checklistsTests
//
//  Created by Jimmy Ho on 12/6/20.
//  Copyright © 2020 Jimmy Ho. All rights reserved.
//

import XCTest
@testable import checklists
import RealmSwift
import ToastSwiftFramework

private let checklistName = "Test Checklist 1"
private let checklistNotes = "Some notes about Checklist1; blah blah blah...\nMore blah blah blah\nAnd more with emojis: 🤪🧐🤷🏼‍♀️"

// WARNING: Running these tests will reset the app's database on whatever simulator this is run on.
class DataModelTests: XCTestCase {

  override func setUpWithError() throws {
    // We're going to test with persisted store, not memory store, against recommendation, because I want to make sure the file stuff is okay.
    DBManager.write {
      DBManager.realm.deleteAll()
    }
  }

  override func tearDownWithError() throws {
    DBManager.write {
      DBManager.realm.deleteAll()
    }
  }

  func testAddNewChecklist() throws {
    let checklist = Checklist(name: "Test Checklist 1", items: [])
    DBManager.write {
      DBManager.realm.add(checklist)
    }
    guard let retrievedChecklist = DBManager.realm.objects(Checklist.self).filter({ $0.id == checklist.id }).first
    else { XCTFail(); return }

    compareChecklists(checklist1: checklist, checklist2: retrievedChecklist)
  }

  private func compareChecklists(checklist1: Checklist, checklist2: Checklist) {
    XCTAssertEqual(checklist1.id, checklist2.id)
    XCTAssertEqual(checklist1.name, checklist2.name)
    XCTAssertEqual(checklist1.notes, checklist2.notes)
    XCTAssertEqual(checklist1.sortNumber, checklist2.sortNumber)
    XCTAssertEqual(checklist1.lastModified, checklist2.lastModified)
    XCTAssertEqual(checklist1.items.count, checklist2.items.count)

    for (item1, item2) in zip(checklist1.items, checklist2.items) {
      compareItems(item1: item1, item2: item2)
    }
  }

  private func compareItems(item1: Item, item2: Item) {
    XCTAssertEqual(item1.id, item2.id)
    XCTAssertEqual(item1.name, item2.name)
    XCTAssertEqual(item1.notes, item2.notes)
    XCTAssertEqual(item1.status, item2.status)
  }
}
