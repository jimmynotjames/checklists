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

 The checklist identifiers are fixed constants rather than fresh UUIDs. Any fresh install seeds
 before its first iCloud import can arrive, so a reinstall, or a second device, on an account that
 already holds the samples seeds them again; with random identifiers that produces two of everything
 and no way to tell the copies apart. Fixed identifiers turn it into an ordinary duplicate-record
 problem, which `dedupeChecklists` resolves.
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

  /// Posted after `dedupeChecklists` deletes anything. Dedupe is a local save, so it raises no
  /// `NSPersistentStoreRemoteChange` of its own; `RemoteChangeObserver` listens for this too, so a
  /// screen showing a deleted copy still hears about it.
  static let didRemoveDuplicates = Notification.Name("SampleData.didRemoveDuplicates")

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
    userDefaults: UserDefaults = .standard,
  ) throws {
    guard !userDefaults.bool(forKey: seededFlagKey) else { return }

    // An upgrading install: its data came from the Realm store, or will arrive from iCloud.
    guard !userDefaults.bool(forKey: legacyLaunchedAtLeastOnceKey) else {
      userDefaults.set(true, forKey: seededFlagKey)
      return
    }

    // If anything is already here, this is not a first launch in any meaningful sense, whatever the
    // flags say. This does *not* catch the sync case: on a fresh install it runs before the first
    // iCloud import, so the store is always empty. `dedupeChecklists` cleans up after that.
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
        sortKey: checklistSortKey,
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
   Removes redundant copies of the built-in samples, and deletes nothing else.

   **The case it exists for.** Every fresh install seeds the three fixed ids before its first iCloud
   import arrives. A reinstall, a second device, or two devices racing on day one therefore leave the
   account holding two or more copies of a sample.

   **The rule, per sample id.** A copy is *pristine* when it is identical to the fixture — name,
   notes, item names, item notes, checked states, order. A copy is *edited* when it has more items
   than the fixture or its checked states differ. Pristine copies are deleted whenever an edited copy
   exists (the user's own original wins over a fresh seed); otherwise all but one elected survivor
   are deleted. Nothing else is ever deleted.

   **A copy with fewer items than the fixture stops the pass for that sample.** CloudKit imports a
   record graph in batches, so a checklist can land before all its items. Read as edited, a
   half-arrived copy would cost every pristine copy here, while the device that sent it, seeing it
   whole, elects a survivor and deletes the rest: no copy left. Nothing is decided for that sample
   while the copy is short — or, if the user really did delete items, ever: an untouched twin beside
   it is the cheaper mistake.

   **Why "edited" ignores text.** The fixture is resolved in the current language, so a copy seeded
   in another language never matches it. Judging edits by text would let two devices in different
   languages each see the other's copy as edited and delete their own, leaving none. Item count and
   checked states are the same in every language, so such copies are simply both kept — rare and
   cosmetic. So is a copy whose only edit is to text: it is kept beside the pristine one.

   It cannot reach a user's own checklists: those carry random per-device ids that never collide.
   In particular this does **not** touch the two-device *upgrade* case, where each device's imported
   checklists keep the random ids Realm gave them — that data must union, and it does.

   **Why the survivor is elected rather than just "the first one".** Every device runs this, possibly
   before another's deletion has synced. If they disagreed about which copy to keep they would delete
   one each and the user would end up with none. The copies are identical, but their *items* carry
   random ids, so the sorted item-id fingerprint differs between copies and reads the same on every
   device, and every device elects the same survivor.

   **The gaps.** Devices judge from what they have synced so far, so a copy can look pristine here
   while the device that holds it knows it is edited; that device deletes the other copy because of
   the edit, this one deletes the edited copy as a non-survivor, and the sample is lost with the
   edit. It happens two ways: the user edits one fresh copy in a day-one race before the other device
   has seen the edit, or a copy the user added items to arrives with only its original rows so far.
   Both need an unlucky moment; closing them would cost a deferred second pass, which it is not
   worth.

   **Deleted samples come back, by decision.** A fresh install always seeds, and this only removes a
   copy when another exists, so samples the user deleted reappear — on every device — after a reinstall
   or a new device. Avoiding it means not seeding until the account is known, and a fresh install
   never opens empty.
   */
  @MainActor
  static func dedupeChecklists(in context: ModelContext) throws {
    let fixtures = generateFirstTimeLaunchChecklists()
    guard !fixtures.isEmpty else { return }

    let stored = try context.fetchChecklistsSorted()
    var didDelete = false

    for fixture in fixtures {
      let copies = stored.filter { $0.id == fixture.id }
      guard !copies.contains(where: { $0.items.count < fixture.items.count }) else { continue }
      let pristine = copies.filter { matchesPristineFixture($0, fixture) }
      let anyEdited = copies.contains { isEditedByStructure($0, fixture) }
      let survivor = anyEdited ? nil : pristine.min { itemFingerprint(of: $0) < itemFingerprint(of: $1) }
      for duplicate in pristine where duplicate !== survivor {
        context.delete(duplicate)
        didDelete = true
      }
    }

    // Never save when nothing changed: a no-op save on a synced store is a pointless write that
    // every other device has to merge.
    guard didDelete else { return }
    AppLog.persistence.notice("dedupe: removed redundant untouched sample checklists.")
    try context.saveChanges(operation: .dedupe)
    NotificationCenter.default.post(name: didRemoveDuplicates, object: nil)
  }

  /// True when `checklist` has items added, checked or unchecked relative to `fixture` — differences
  /// that read the same in every language, unlike its text.
  private static func isEditedByStructure(_ checklist: Checklist, _ fixture: ChecklistFixture) -> Bool {
    let items = checklist.items
    guard items.count == fixture.items.count else { return true }
    return zip(items, fixture.items).contains { item, expected in (item.status == .checked) != expected.isChecked }
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
  ///
  /// **Changing a sample's item count or which items start checked needs new checklist ids.**
  /// `dedupeChecklists` judges edits by structure, so devices on builds with different structures
  /// misread each other's fresh copies: with different checked states each judges the other's copy
  /// edited and deletes its own, leaving none. Wording changes are safe: text differences are never
  /// taken as edits.
  static func generateFirstTimeLaunchChecklists() -> [ChecklistFixture] {
    [
      ChecklistFixture(
        id: morningRoutineId,
        name: String(
          localized: "sample.morningRoutine.name",
          defaultValue: "Morning Routine",
          comment: "Demo checklist 1 of 3: name of the everyday morning-routine list every new install starts with.",
        ),
        items: [
          ItemFixture(
            name: String(
              localized: "sample.morningRoutine.item1",
              defaultValue: "START COFFEE MAKER",
              comment: "Morning routine demo item 1 of 6. Deliberately in capitals, like a hand-written reminder. Swap the drink or appliance for the local morning norm.",
            ),
            isChecked: true,
          ),
          ItemFixture(name: String(localized: "sample.morningRoutine.item2", defaultValue: "Yoga/meditation", comment: "Morning routine demo item 2 of 6."), isChecked: true),
          ItemFixture(name: String(localized: "sample.morningRoutine.item3", defaultValue: "Traffic and weather reports", comment: "Morning routine demo item 3 of 6."), isChecked: true),
          ItemFixture(name: String(localized: "sample.morningRoutine.item4", defaultValue: "Breakfast", comment: "Morning routine demo item 4 of 6."), isChecked: true),
          ItemFixture(name: String(localized: "sample.morningRoutine.item5", defaultValue: "Journaling", comment: "Morning routine demo item 5 of 6.")),
          ItemFixture(
            name: String(
              localized: "sample.morningRoutine.item6",
              defaultValue: "Argue politics on Facebook",
              comment: "Morning routine demo item 6 of 6. Wry, self-aware joke; keep the tone and name the network people there actually argue on.",
            ),
            isChecked: true,
          ),
        ],
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
              comment: "Note under the Wallet/ID packing item. Adapt to the documents people there carry for flights, border crossings, and driving.",
            ),
          ),
          ItemFixture(name: String(localized: "sample.weekendGetaway.item3", defaultValue: "Prescriptions, medicines, supplements", comment: "Weekend packing demo item 3 of 12."), isChecked: true),
          ItemFixture(
            name: String(localized: "sample.weekendGetaway.item4", defaultValue: "Toiletries bag", comment: "Weekend packing demo item 4 of 12."),
            notes: String(
              localized: "sample.weekendGetaway.item4.notes",
              defaultValue: "Small liquids only in separate bag if flying and in carry-on.",
              comment: "Note under the toiletries packing item about the airline liquids rule.",
            ),
            isChecked: true,
          ),
          ItemFixture(name: String(localized: "sample.weekendGetaway.item5", defaultValue: "Sun screen", comment: "Weekend packing demo item 5 of 12.")),
          ItemFixture(name: String(localized: "sample.weekendGetaway.item6", defaultValue: "Headphones", comment: "Weekend packing demo item 6 of 12.")),
          ItemFixture(name: String(
            localized: "sample.weekendGetaway.item7",
            defaultValue: "Book, iPad, Kindle...",
            comment: "Weekend packing demo item 7 of 12: things to read. Keep Apple product names as Apple writes them; swap Kindle for the local e-reader if another dominates.",
          )),
          ItemFixture(name: String(
            localized: "sample.weekendGetaway.item8",
            defaultValue: "Rain/wind items",
            comment: "Weekend packing demo item 8 of 12: rain and wind gear. Adapt to the local climate.",
          )),
          ItemFixture(name: String(localized: "sample.weekendGetaway.item9", defaultValue: "Sunglasses", comment: "Weekend packing demo item 9 of 12."), isChecked: true),
          ItemFixture(name: String(localized: "sample.weekendGetaway.item10", defaultValue: "Sunhat", comment: "Weekend packing demo item 10 of 12."), isChecked: true),
          ItemFixture(name: String(localized: "sample.weekendGetaway.item11", defaultValue: "Swimsuit", comment: "Weekend packing demo item 11 of 12.")),
          ItemFixture(name: String(localized: "sample.weekendGetaway.item12", defaultValue: "Pool shoes", comment: "Weekend packing demo item 12 of 12.")),
        ],
      ),
      ChecklistFixture(
        id: preTripId,
        name: String(localized: "sample.preTrip.name", defaultValue: "Pre-Trip Checklist", comment: "Demo checklist 3 of 3: name of the leaving-the-house-before-a-trip list."),
        items: [
          ItemFixture(name: String(localized: "sample.preTrip.item1", defaultValue: "Set up auto-reply on email accounts", comment: "Pre-trip demo item 1 of 11.")),
          ItemFixture(name: String(
            localized: "sample.preTrip.item2",
            defaultValue: "Post office: hold mail",
            comment: "Pre-trip demo item 2 of 11: pausing postal delivery. Adapt to what a local does about mail before a trip, or a different pre-trip errand if that service does not exist there.",
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
              comment: "Note under the heater item. Adapt to the local climate; a warm-climate locale may replace the freezing-pipes concern.",
            ),
          ),
          ItemFixture(name: String(localized: "sample.preTrip.item10", defaultValue: "Check stoves, oven are off", comment: "Pre-trip demo item 10 of 11.")),
          ItemFixture(name: String(localized: "sample.preTrip.item11", defaultValue: "Lock doors and windows", comment: "Pre-trip demo item 11 of 11.")),
        ],
      ),
    ]
  }
}
