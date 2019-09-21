//
//  SampleData.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation
import RealmSwift

class SampleData {
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

    checklists.append(Checklist(name: "Testing Cell Reuse",
                                sortNumber: 5.0,
                                items: (1...30).map({ Item(name: "some item \($0)") })))

    checklists.append(Checklist(name: "Long List 1",
                                sortNumber: 6.0,
                                items: (1...30).map({
                                  Item(name: "some item \($0)",
                                       notes: $0 % 2 == 0 ? ($0 % 3 == 0 ? nil : "some for \($0)") : "some\nodd\nnotes for \($0)" ) })))

    DBManager.write {
      realm.add(checklists)
    }
  }

  static func insertTestData2() {
    let realm = DBManager.realm

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
      realm.add(checklists)
    }

  }

  static func insertFirstTimeLaunchData() {
    let realm = DBManager.realm

    var checklists: [Checklist] = []

    checklists.append(Checklist(name: "Weekend Getaway Essentials",
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
    ]))

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

    checklists.append(Checklist(name: "Morning Routine",
                                sortNumber: 3.0,
                                items: [Item(name: "START COFFEE MAKER"),
                                        Item(name: "Yoga/meditation"),
                                        Item(name: "Traffic and weather reports"),
                                        Item(name: "Breakfast"),
                                        Item(name: "Journaling"),
                                        Item(name: "Argue politics on Twitter or Facebook", notes: "(kidding!)")
    ]))

    DBManager.write {
      realm.add(checklists)
    }
  }
}
