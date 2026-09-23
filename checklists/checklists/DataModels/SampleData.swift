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
 turn it into an ordinary duplicate-record problem, which `dedupeChecklists` resolves.
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

  // Plain values rather than models, so the fixture can be declared without a context and materialized the same way the importer materializes Realm data.

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

   **The case it exists for.** Two devices both install fresh and race, each seeding the same
   three fixed ids before either's upload reaches the other — the account then holds two of each.

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

  /// Resolved at call time, so a first launch seeds the store in the device's language. The
  /// `sample.*` keys are transcreated per locale, not translated (localization-spec.md):
  /// each item is what a person there would write on such a list. Once seeded the rows are data
  /// and stay in that language.
  static func generateFirstTimeLaunchChecklists() -> [ChecklistFixture] {
    [
      ChecklistFixture(
        id: morningRoutineId,
        name: String(
          localized: "sample.morningRoutine.name",
          defaultValue: "Morning Routine",
          comment: "Demo checklist 1 of 3: name of the everyday morning-routine list every new install starts with."
        ),
        items: [
          ItemFixture(
            name: String(
              localized: "sample.morningRoutine.item1",
              defaultValue: "START COFFEE MAKER",
              comment: "Morning routine demo item 1 of 6. Deliberately in capitals, like a hand-written reminder. Swap the drink or appliance for the local morning norm."
            ),
            isChecked: true
          ),
          ItemFixture(name: String(localized: "sample.morningRoutine.item2", defaultValue: "Yoga/meditation", comment: "Morning routine demo item 2 of 6."), isChecked: true),
          ItemFixture(name: String(localized: "sample.morningRoutine.item3", defaultValue: "Traffic and weather reports", comment: "Morning routine demo item 3 of 6."), isChecked: true),
          ItemFixture(name: String(localized: "sample.morningRoutine.item4", defaultValue: "Breakfast", comment: "Morning routine demo item 4 of 6."), isChecked: true),
          ItemFixture(name: String(localized: "sample.morningRoutine.item5", defaultValue: "Journaling", comment: "Morning routine demo item 5 of 6.")),
          ItemFixture(
            name: String(
              localized: "sample.morningRoutine.item6",
              defaultValue: "Argue politics on Facebook",
              comment: "Morning routine demo item 6 of 6. Wry, self-aware joke; keep the tone and name the network people there actually argue on."
            ),
            isChecked: true
          ),
        ]
      ),
      ChecklistFixture(
        id: weekendGetawayId,
        name: String(localized: "sample.weekendGetaway.name", defaultValue: "Weekend Getaway Essentials", comment: "Demo checklist 2 of 3: name of the packing list for a short trip."),
        items: [
          ItemFixture(name: String(localized: "sample.weekendGetaway.item1", defaultValue: "Phone charger", comment: "Weekend packing demo item 1 of 12.")),
          ItemFixture(
            name: String(localized: "sample.weekendGetaway.item2", defaultValue: "Wallet/ID", comment: "Weekend packing demo item 2 of 12."),
            notes: String(
              localized: "sample.weekendGetaway.item2.notes",
              defaultValue: "Proper ID (ID for air travel, international, driver license for roadtrip, etc.)",
              comment: "Note under the Wallet/ID packing item. Adapt to the documents people there carry for flights, border crossings, and driving."
            )
          ),
          ItemFixture(name: String(localized: "sample.weekendGetaway.item3", defaultValue: "Prescriptions, medicines, supplements", comment: "Weekend packing demo item 3 of 12."), isChecked: true),
          ItemFixture(
            name: String(localized: "sample.weekendGetaway.item4", defaultValue: "Toiletries bag", comment: "Weekend packing demo item 4 of 12."),
            notes: String(
              localized: "sample.weekendGetaway.item4.notes",
              defaultValue: "Small liquids only in separate bag if flying and in carry-on.",
              comment: "Note under the toiletries packing item about the airline liquids rule."
            ),
            isChecked: true
          ),
          ItemFixture(name: String(localized: "sample.weekendGetaway.item5", defaultValue: "Sun screen", comment: "Weekend packing demo item 5 of 12.")),
          ItemFixture(name: String(localized: "sample.weekendGetaway.item6", defaultValue: "Headphones", comment: "Weekend packing demo item 6 of 12.")),
          ItemFixture(name: String(
            localized: "sample.weekendGetaway.item7",
            defaultValue: "Book, iPad, Kindle...",
            comment: "Weekend packing demo item 7 of 12: things to read. Keep Apple product names as Apple writes them; swap Kindle for the local e-reader if another dominates."
          )),
          ItemFixture(name: String(
            localized: "sample.weekendGetaway.item8",
            defaultValue: "Rain/wind items",
            comment: "Weekend packing demo item 8 of 12: rain and wind gear. Adapt to the local climate."
          )),
          ItemFixture(name: String(localized: "sample.weekendGetaway.item9", defaultValue: "Sunglasses", comment: "Weekend packing demo item 9 of 12."), isChecked: true),
          ItemFixture(name: String(localized: "sample.weekendGetaway.item10", defaultValue: "Sunhat", comment: "Weekend packing demo item 10 of 12."), isChecked: true),
          ItemFixture(name: String(localized: "sample.weekendGetaway.item11", defaultValue: "Swimsuit", comment: "Weekend packing demo item 11 of 12.")),
          ItemFixture(name: String(localized: "sample.weekendGetaway.item12", defaultValue: "Pool shoes", comment: "Weekend packing demo item 12 of 12.")),
        ]
      ),
      ChecklistFixture(
        id: preTripId,
        name: String(localized: "sample.preTrip.name", defaultValue: "Pre-Trip Checklist", comment: "Demo checklist 3 of 3: name of the leaving-the-house-before-a-trip list."),
        items: [
          ItemFixture(name: String(localized: "sample.preTrip.item1", defaultValue: "Set up auto-reply on email accounts", comment: "Pre-trip demo item 1 of 11.")),
          ItemFixture(name: String(
            localized: "sample.preTrip.item2",
            defaultValue: "Post office: hold mail",
            comment: "Pre-trip demo item 2 of 11: pausing postal delivery. Adapt to what a local does about mail before a trip, or a different pre-trip errand if that service does not exist there."
          )),
          ItemFixture(name: String(localized: "sample.preTrip.item3", defaultValue: "Pet care arrangements", comment: "Pre-trip demo item 3 of 11.")),
          ItemFixture(name: String(localized: "sample.preTrip.item4", defaultValue: "Plant care, housesitting arrangements", comment: "Pre-trip demo item 4 of 11.")),
          ItemFixture(name: String(localized: "sample.preTrip.item5", defaultValue: "School absence arrangements", comment: "Pre-trip demo item 5 of 11.")),
          ItemFixture(name: String(localized: "sample.preTrip.item6", defaultValue: "Send travel itineraries to trusted friend/relative", comment: "Pre-trip demo item 6 of 11.")),
          ItemFixture(name: String(localized: "sample.preTrip.item7", defaultValue: "Unplug appliances", comment: "Pre-trip demo item 7 of 11.")),
          ItemFixture(name: String(localized: "sample.preTrip.item8", defaultValue: "Stow away valuables", comment: "Pre-trip demo item 8 of 11.")),
          ItemFixture(
            name: String(localized: "sample.preTrip.item9", defaultValue: "Turn off heater or A/C", comment: "Pre-trip demo item 9 of 11: heating or cooling. Adapt to the local climate."),
            notes: String(
              localized: "sample.preTrip.item9.notes",
              defaultValue: "Or set minimum temp to prevent freezing pipes.",
              comment: "Note under the heater item. Adapt to the local climate; a warm-climate locale may replace the freezing-pipes concern."
            )
          ),
          ItemFixture(name: String(localized: "sample.preTrip.item10", defaultValue: "Check stoves, oven are off", comment: "Pre-trip demo item 10 of 11.")),
          ItemFixture(name: String(localized: "sample.preTrip.item11", defaultValue: "Lock doors and windows", comment: "Pre-trip demo item 11 of 11.")),
        ]
      ),
    ]
  }
}
