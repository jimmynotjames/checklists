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
import Toast

private let checklistName = "Test Checklist 1"
private let checklistNotes = "Some notes about Checklist1; blah blah blah...\nMore blah blah blah\nAnd more with emojis: 🤪🧐🤷🏼‍♀️"

private let itemName1 = "Masquerade mask"
private let itemNotes1 = "Match to final choice of shoes"
private let itemName2 = "Contact lenses"
private let itemName3 = "flip flops"
private let itemName4 = "tiara"
private let itemNotes4 = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

// WARNING: Running these tests will reset the app's database on whatever simulator this is run on.
class DataModelTests: XCTestCase {

  override func setUpWithError() throws {
    // We're going to test with persisted store, not memory store, against recommendation, because I want to make sure the file stuff is okay.
    DBManager.write { realm in
      realm.deleteAll()
    }
  }

  override func tearDownWithError() throws {
    DBManager.write { realm in
      realm.deleteAll()
    }
  }

  func testCreateEmptyChecklist1() throws {
    let checklist = Checklist(name: "Test Checklist 1", items: [])
    DBManager.write { realm in
      realm.add(checklist)
    }
    guard let retrievedChecklist = DBManager.realm.objects(Checklist.self).filter({ $0.id == checklist.id }).first
    else { XCTFail(); return }

    compareChecklists(checklist1: checklist, checklist2: retrievedChecklist)
  }

  func testCreateChecklist2() throws {
    let checklist = Checklist(name: checklistName, notes: checklistNotes, sortNumber: nil, items: [])
    DBManager.write { realm in
      realm.add(checklist)
    }
    guard let retrievedChecklist = DBManager.realm.objects(Checklist.self).filter({ $0.id == checklist.id }).first
    else { XCTFail(); return }

    compareChecklists(checklist1: checklist, checklist2: retrievedChecklist)
  }

  func testCreateChecklistWithItems() throws {
    let items: [Item] = [Item(name: itemName1, notes: itemNotes1), Item(name: itemName2), Item(name: itemName3), Item(name: itemName4, notes: itemNotes4)]
    items[1].toggleStatus()
    items[3].toggleStatus()
    let checklist = Checklist(name: checklistName, notes: checklistNotes, sortNumber: nil, items: items)
    DBManager.write { realm in
      realm.add(checklist)
    }
    guard let retrievedChecklist = DBManager.getRealm().objects(Checklist.self).filter({ $0.id == checklist.id }).first
    else { XCTFail(); return }

    compareChecklists(checklist1: checklist, checklist2: retrievedChecklist)
  }

  func testChecklistPercentComplete() throws {
    let items: [Item] = [Item(name: itemName1, notes: itemNotes1), Item(name: itemName2), Item(name: itemName3), Item(name: itemName4, notes: itemNotes4)]
    items[1].toggleStatus()
    items[3].toggleStatus()
    let checklist = Checklist(name: checklistName, notes: checklistNotes, sortNumber: nil, items: items)

    XCTAssertEqual(checklist.percentageComplete, 0.50)
    items[1].toggleStatus()
    XCTAssertEqual(checklist.percentageComplete, 0.25)
    items[3].toggleStatus()
    XCTAssertEqual(checklist.percentageComplete, 0.0)
    checklist.items.removeAll() // Test empty case (can cause divide-by-zero)
    XCTAssertEqual(checklist.percentageComplete, 0.0)
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
    XCTAssertEqual(item1.isChecked, item2.isChecked)
  }
}
