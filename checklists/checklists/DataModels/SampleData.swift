//
//  SampleData.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//

import Foundation
import SwiftData

/**
 The three checklists a brand-new install starts with.

 **This data set is also the UI test fixture.** `SampleDataTests` asserts its exact shape and
 `checklistsUITests` navigates by these names, so changing the content means updating both.

 The checklist identifiers are fixed constants rather than fresh UUIDs. Two devices signed into the
 same iCloud account each seed themselves on first launch, before either has synced; with random
 identifiers that produces two of everything and no way to tell the copies apart. Fixed identifiers
 turn it into an ordinary duplicate-record problem that can be resolved deterministically once
 sync arrives.
 */
enum SampleData {
  // Stable for the life of the app. Never regenerate these.
  static let morningRoutineId = "C4EC1157-0000-4000-A000-000000000001"
  static let weekendGetawayId = "C4EC1157-0000-4000-A000-000000000002"
  static let preTripId = "C4EC1157-0000-4000-A000-000000000003"

  /// Set once the fixture has been seeded and saved.
  static let seededFlagKey = "sampleDataSeededV1"

  /// The pre-SwiftData first-launch flag. Still read, never used for anything new: an install that
  /// has this set has launched before, so it already owns its data and must not be re-seeded.
  static let legacyLaunchedAtLeastOnceKey = "launchedAtLeastOnce"

  // MARK: - Fixture description

  //
  // Plain values rather than models, so the fixture can be declared without a context and
  // materialized the same way the importer materializes Realm data.

  struct ChecklistFixture: Equatable {
    let id: String
    let name: String
    var notes: String?
    let items: [ItemFixture]
  }

  struct ItemFixture: Equatable {
    let name: String
    var notes: String?
    var isChecked: Bool = false
  }

  // MARK: - Seeding

  static func insertFirstTimeLaunchDataIfNeeded(
    into context: ModelContext,
    userDefaults: UserDefaults = .standard
  ) throws {
    guard !userDefaults.bool(forKey: seededFlagKey) else { return }

    // An upgrading install: its data came from the Realm store, or will arrive from iCloud.
    guard !userDefaults.bool(forKey: legacyLaunchedAtLeastOnceKey) else {
      userDefaults.set(true, forKey: seededFlagKey)
      return
    }

    // Belt and braces for the sync case: if anything is already here, this is not a first launch
    // in any meaningful sense, whatever the flags say.
    guard try context.fetchCount(FetchDescriptor<Checklist>()) == 0 else {
      userDefaults.set(true, forKey: seededFlagKey)
      return
    }

    try seed(into: context)

    userDefaults.set(true, forKey: seededFlagKey)
    userDefaults.set(true, forKey: legacyLaunchedAtLeastOnceKey)
    AppLog.bootstrap.info("bootstrap.seededFirstLaunchData")
  }

  /// Materializes the fixture into `context` unconditionally. Callers decide whether it should run.
  static func seed(into context: ModelContext) throws {
    var checklistSortKey = SortKeyReorder.step
    for fixture in generateFirstTimeLaunchChecklists() {
      let checklist = Checklist(
        id: fixture.id,
        name: fixture.name,
        notes: fixture.notes,
        sortKey: checklistSortKey
      )
      context.insert(checklist)

      var itemSortKey = SortKeyReorder.step
      for itemFixture in fixture.items {
        let item = Item(name: itemFixture.name, notes: itemFixture.notes, sortKey: itemSortKey)
        item.status = itemFixture.isChecked ? .checked : .unchecked
        context.insert(item)
        item.checklist = checklist
        itemSortKey += SortKeyReorder.step
      }

      checklistSortKey += SortKeyReorder.step
    }
    try context.saveChanges(operation: .sampleSeed)
  }

  static func clearDatabase(in context: ModelContext) throws {
    try context.delete(model: Checklist.self)
    try context.delete(model: Item.self)
    try context.saveChanges(operation: .delete)
  }

  // MARK: - The fixture itself

  /**
   REMINDER: This data set is also used for automated testing.
   If we make adjustments to this, we should either update the tests or duplicate this test set.
   */
  static func generateFirstTimeLaunchChecklists() -> [ChecklistFixture] {
    [
      ChecklistFixture(
        id: morningRoutineId,
        name: "Morning Routine",
        items: [
          ItemFixture(name: "START COFFEE MAKER", isChecked: true),
          ItemFixture(name: "Yoga/meditation", isChecked: true),
          ItemFixture(name: "Traffic and weather reports", isChecked: true),
          ItemFixture(name: "Breakfast", isChecked: true),
          ItemFixture(name: "Journaling"),
          ItemFixture(name: "Argue politics on Facebook", isChecked: true),
        ]
      ),
      ChecklistFixture(
        id: weekendGetawayId,
        name: "Weekend Getaway Essentials",
        items: [
          ItemFixture(name: "Phone charger"),
          ItemFixture(name: "Wallet/ID", notes: "Proper ID (ID for air travel, international, driver license for roadtrip, etc.)"),
          ItemFixture(name: "Prescriptions, medicines, supplements", isChecked: true),
          ItemFixture(name: "Toiletries bag", notes: "Small liquids only in separate bag if flying and in carry-on.", isChecked: true),
          ItemFixture(name: "Sun screen"),
          ItemFixture(name: "Headphones"),
          ItemFixture(name: "Book, iPad, Kindle..."),
          ItemFixture(name: "Rain/wind items"),
          ItemFixture(name: "Sunglasses", isChecked: true),
          ItemFixture(name: "Sunhat", isChecked: true),
          ItemFixture(name: "Swimsuit"),
          ItemFixture(name: "Pool shoes"),
        ]
      ),
      ChecklistFixture(
        id: preTripId,
        name: "Pre-Trip Checklist",
        items: [
          ItemFixture(name: "Set up auto-reply on email accounts"),
          ItemFixture(name: "Post office: hold mail"),
          ItemFixture(name: "Pet care arrangements"),
          ItemFixture(name: "Plant care, housesitting arrangements"),
          ItemFixture(name: "School absence arrangements"),
          ItemFixture(name: "Send travel itineraries to trusted friend/relative"),
          ItemFixture(name: "Unplug appliances"),
          ItemFixture(name: "Stow away valuables"),
          ItemFixture(name: "Turn off heater or A/C", notes: "Or set minimum temp to prevent freezing pipes."),
          ItemFixture(name: "Check stoves, oven are off"),
          ItemFixture(name: "Lock doors and windows"),
        ]
      ),
    ]
  }
}
