//
//  SampleData.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation
import RealmSwift

@MainActor class SampleData {
  static func clearDatabase() {
    print("DEBUG: Clearing database...")
    let realm = DBManager.realm
    DBManager.write {
      realm.deleteAll()
    }
    DBManager.write {
      realm.add(Group())
    }
  }

  static func insertTestData() {
    print("DEBUG: Inserting test data...")
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

    checklists.append(Checklist(name: "Testing Cell Reuse",
                                sortNumber: 5.0,
                                items: (1...30).map({ Item(name: "some item \($0)") })))

    checklists.append(Checklist(name: "Long List 1",
                                sortNumber: 6.0,
                                items: (1...30).map({
                                  Item(name: "some item \($0)",
                                       notes: $0 % 2 == 0 ? ($0 % 3 == 0 ? nil : "some for \($0)") : "some\nodd\nnotes for \($0)" ) })))

    DBManager.write {
      DBManager.getGroup().checklists.append(objectsIn: checklists)
    }
  }

  static func insertTestData2() {
    var checklists: [Checklist] = []

    checklists.append(Checklist(name: "Test List - Long List",
                                sortNumber: 5.0,
                                items: (1...30).map({ Item(name: "some item \($0)") })))

    checklists.append(Checklist(name: "Test List - Long List with notes", notes: "Notes\nnotes\nnotes",
                                sortNumber: 6.0,
                                items: (1...30).map({
                                  Item(name: "some item \($0)",
                                       notes: $0 % 2 == 0 ? ($0 % 3 == 0 ? nil : "some for \($0)") : "some\nodd\nnotes for \($0)" ) })))

    DBManager.write {
      DBManager.getGroup().checklists.append(objectsIn: checklists)
    }

  }

  static func insertFirstTimeLaunchDataV1_0() {
    let realm = DBManager.realm

    DBManager.write {
      realm.add(generateFirstTimeLaunchChecklists())
    }
  }


  static func insertFirstTimeLaunchDataV1_1() {
    let realm = DBManager.realm

    let group = Group()
    group.checklists.append(objectsIn: generateFirstTimeLaunchChecklists())
    DBManager.write {
      realm.add(group)
    }
  }

  /*
   REMINDER: This data set is also used for automated testing.
   If we make adjustments to this, we should either update the tests or duplicate this test set.
   */
  static func generateFirstTimeLaunchChecklists() -> [Checklist] {
    var checklists: [Checklist] = []

    let checklist1 = Checklist(name: "Morning Routine",
                               notes: "Sample checklist. Customize away!",
                               sortNumber: 3.0,
                               items: [Item(name: "START COFFEE MAKER"),
                                       Item(name: "Yoga/meditation"),
                                       Item(name: "Traffic and weather reports"),
                                       Item(name: "Breakfast"),
                                       Item(name: "Journaling"),
                                       Item(name: "Argue politics on Facebook")
                               ])
    checklist1.items[0].status = .checked
    checklist1.items[1].status = .checked
    checklist1.items[2].status = .checked
    checklist1.items[3].status = .checked
    checklist1.items[5].status = .checked

    checklists.append(checklist1)

    let checklist2 = Checklist(name: "Weekend Getaway Essentials",
                               sortNumber: 1.0,
                               items: [Item(name: "Phone charger"),
                                       Item(name: "Wallet/ID", notes: "Proper ID (ID for air travel, international, driver license for roadtrip, etc.)"),
                                       Item(name: "Prescriptions, medicines, supplements"),
                                       Item(name: "Toiletries bag", notes: "Small liquids only in separate bag if flying and in carry-on."),
                                       Item(name: "Sun screen"),
                                       Item(name: "Headphones"),
                                       Item(name: "Book, iPad, Kindle..."),
                                       Item(name: "Rain/wind items"),
                                       Item(name: "Sunglasses"),
                                       Item(name: "Sunhat"),
                                       Item(name: "Swimsuit"),
                                       Item(name: "Pool shoes")
                               ])
    checklist2.items[2].status = .checked
    checklist2.items[3].status = .checked
    checklist2.items[8].status = .checked
    checklist2.items[9].status = .checked

    checklists.append(checklist2)

    checklists.append(Checklist(name: "Pre-Trip Checklist",
                                sortNumber: 2.0,
                                items: [Item(name: "Set up auto-reply on email accounts"),
                                        Item(name: "Post office: hold mail"),
                                        Item(name: "Pet care arrangements"),
                                        Item(name: "Plant care, housesitting arrangements"),
                                        Item(name: "School absence arrangements"),
                                        Item(name: "Send travel itineraries to trusted friend/relative"),
                                        Item(name: "Unplug appliances"),
                                        Item(name: "Stow away valuables"),
                                        Item(name: "Turn off heater or A/C", notes: "Or set minimum temp to prevent freezing pipes."),
                                        Item(name: "Check stoves, oven are off"),
                                        Item(name: "Lock doors and windows")
    ]))

    return checklists
  }

  static func populateWithSampleData(realm: Realm) {
    let checklists = generateFirstTimeLaunchChecklists()
    let group = Group()
    group.checklists.append(objectsIn: checklists)
    try! realm.write {
      realm.add(group)
    }
  }
}
