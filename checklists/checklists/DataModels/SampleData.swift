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

  // MARK: - Duplicate sample cleanup

  /**
   Collapses duplicate copies of the built-in samples that two devices can each create before their
   first sync, and deletes nothing else.

   **The case it exists for.** Two devices both install fresh and race: A seeds the three fixed-id
   samples and uploads; B launches before A's records arrive, finds an empty store, and seeds the
   same three ids. The account then holds two of each. (If B launches after A's data lands, the
   emptiness check in `insertFirstTimeLaunchDataIfNeeded` means B never seeds and none of this
   applies.)

   **Why it is safe.** A copy is removed only when it is identical to the fixture this app ships —
   name, notes, item names, item notes, checked states, order — *and* another identical copy shares
   its `id`. Two such records were written seconds apart by this code and never seen by anyone, so
   they are indistinguishable and dropping one loses nothing by definition. Any edit at all makes a
   copy stop matching, and then both are kept.

   It cannot reach a user's own checklists: those carry random per-device ids that never collide.
   In particular this does **not** touch the two-device *upgrade* case, where each device's imported
   checklists keep the random ids Realm gave them — that data must union, and it does.

   **Why the survivor is elected rather than just "the first one".** Both devices run this, possibly
   before either's deletion has synced. If they disagreed about which copy to keep they would delete
   one each and the user would end up with none. The two checklists are identical, but their *items*
   carry random ids, so the sorted item-id fingerprint is a value that differs between the copies and
   reads the same on every device. Both devices therefore elect the same survivor and converge on
   exactly one, whether they run seconds or days apart.
   */
  @MainActor
  static func dedupeChecklists(in context: ModelContext) throws {
    let fixtures = generateFirstTimeLaunchChecklists()
    guard !fixtures.isEmpty else { return }

    let stored = try context.fetchChecklistsSorted()
    var didDelete = false

    for fixture in fixtures {
      let identicalCopies = stored.filter { $0.id == fixture.id && matchesPristineFixture($0, fixture) }
      guard identicalCopies.count > 1 else { continue }

      let survivor = identicalCopies.min { itemFingerprint(of: $0) < itemFingerprint(of: $1) }
      for duplicate in identicalCopies where duplicate !== survivor {
        context.delete(duplicate)
        didDelete = true
      }
    }

    // Never save when nothing changed: a no-op save on a synced store is a pointless write that
    // every other device has to merge.
    guard didDelete else { return }
    AppLog.persistence.notice("dedupe: collapsed duplicate untouched sample checklists.")
    try context.saveChanges(operation: .dedupe)
  }

  /// True when `checklist` is exactly as this app seeded it — nothing added, removed, renamed,
  /// re-ordered, re-noted, checked or unchecked.
  static func matchesPristineFixture(_ checklist: Checklist, _ fixture: ChecklistFixture) -> Bool {
    guard checklist.name == fixture.name, checklist.notes == fixture.notes else { return false }

    let items = checklist.items
    guard items.count == fixture.items.count else { return false }

    return zip(items, fixture.items).allSatisfy { item, expected in
      item.name == expected.name
        && item.notes == expected.notes
        && (item.status == .checked) == expected.isChecked
    }
  }

  /// A value that distinguishes two otherwise-identical sample copies and reads the same on every
  /// device. The checklists match field for field; their items' random ids do not.
  private static func itemFingerprint(of checklist: Checklist) -> String {
    checklist.items.map(\.id).sorted().joined(separator: ",")
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
