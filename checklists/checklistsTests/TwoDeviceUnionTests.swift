//
//  TwoDeviceUnionTests.swift
//  checklistsTests
//

@testable import checklists
import RealmSwift
import SwiftData
import XCTest

/**
 Guards the requirement that two devices which never synced must end up with **both** sets of
 checklists, not one of them.

 A user on v1.1.0 with an iPad and an iPhone has a different set of checklists on each, because
 there was no sync. When both upgrade, the union has to survive. It does, for a reason that is easy
 to break by accident: v1.1.0 minted `NSUUID().uuidString` per record on each device independently,
 and `LegacyRealmImporter` preserves those ids, so the two sets are disjoint and neither overwrites
 the other.

 The obvious "improvement" that would break it is rewriting an imported checklist's id to something
 canonical — matching a sample by name, say — which would make the two devices' copies collide and
 silently discard one device's edits and checked states. These tests exist to fail loudly if anyone
 tries it.

 See the doc comment on `DataModelTests` for why this class is `nonisolated` at the type level with
 individual `@MainActor` test methods.
 */
nonisolated final class TwoDeviceUnionTests: XCTestCase {
  private var fixtureDirectory: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    fixtureDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("two-device-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: fixtureDirectory)
    fixtureDirectory = nil
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  /// Writes a v1.1.0-shaped store — a `Group` holding checklists in display order, every record
  /// carrying a fresh random id, exactly as that release minted them.
  @MainActor private func writeDeviceStore(
    named deviceName: String,
    checklists: [(String, [String])],
    checkedItemNames: Set<String> = []
  ) throws -> Realm.Configuration {
    let url = fixtureDirectory.appendingPathComponent("\(deviceName).realm")
    let configuration = LegacyRealmImporter.legacyConfiguration(fileURL: url)
    let realm = try Realm(configuration: configuration)
    try realm.write {
      let group = LegacyGroup()
      for (checklistName, itemNames) in checklists {
        let checklist = LegacyChecklist()
        checklist.name = checklistName
        for itemName in itemNames {
          let item = LegacyItem()
          item.name = itemName
          item.statusRaw = checkedItemNames.contains(itemName) ? 1 : 0
          checklist.items.append(item)
        }
        group.checklists.append(checklist)
      }
      realm.add(group)
    }
    return configuration
  }

  @MainActor private func freshDefaults() -> UserDefaults {
    let suite = "TwoDeviceUnionTests-\(UUID().uuidString)"
    addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
    return UserDefaults(suiteName: suite)!
  }

  // MARK: - Union

  /// The headline requirement: both devices' data survives into one store.
  @MainActor func testTwoIndependentStoresUnionRatherThanOverwrite() throws {
    let deviceA = try writeDeviceStore(named: "iPad", checklists: [
      ("Garden", ["Water tomatoes", "Prune roses"]),
      ("Reading", ["Finish chapter 4"]),
    ])
    let deviceB = try writeDeviceStore(named: "iPhone", checklists: [
      ("Groceries", ["Milk", "Bread"]),
      ("Gym", ["Squats"]),
    ])

    // One store stands in for the shared CloudKit account both devices sync into.
    let context = try ModelContext(TestModelContainer.make())
    try LegacyRealmImporter.importIfNeeded(into: context, userDefaults: freshDefaults(), configuration: deviceA)
    try LegacyRealmImporter.importIfNeeded(into: context, userDefaults: freshDefaults(), configuration: deviceB)

    let names = try context.fetchChecklistsSorted().map(\.name)
    XCTAssertEqual(names.count, 4, "Both devices' checklists must survive; neither set may overwrite the other.")
    XCTAssertEqual(Set(names), ["Garden", "Reading", "Groceries", "Gym"])
  }

  /// Items must come across with their parents, not just the checklists.
  @MainActor func testUnionPreservesEveryItemFromBothDevices() throws {
    let deviceA = try writeDeviceStore(named: "iPad", checklists: [("Garden", ["Water tomatoes", "Prune roses"])])
    let deviceB = try writeDeviceStore(named: "iPhone", checklists: [("Groceries", ["Milk", "Bread"])])

    let context = try ModelContext(TestModelContainer.make())
    try LegacyRealmImporter.importIfNeeded(into: context, userDefaults: freshDefaults(), configuration: deviceA)
    try LegacyRealmImporter.importIfNeeded(into: context, userDefaults: freshDefaults(), configuration: deviceB)

    let byName = try Dictionary(uniqueKeysWithValues: context.fetchChecklistsSorted().map { ($0.name, $0) })
    XCTAssertEqual(byName["Garden"]?.items.map(\.name), ["Water tomatoes", "Prune roses"])
    XCTAssertEqual(byName["Groceries"]?.items.map(\.name), ["Milk", "Bread"])
  }

  /// Two checklists that happen to share a name are still two checklists. Merging by name would be
  /// the tempting shortcut and would destroy one device's copy.
  @MainActor func testIdenticallyNamedChecklistsOnBothDevicesAreKeptSeparate() throws {
    let deviceA = try writeDeviceStore(named: "iPad", checklists: [("Groceries", ["Milk"])])
    let deviceB = try writeDeviceStore(named: "iPhone", checklists: [("Groceries", ["Bread"])])

    let context = try ModelContext(TestModelContainer.make())
    try LegacyRealmImporter.importIfNeeded(into: context, userDefaults: freshDefaults(), configuration: deviceA)
    try LegacyRealmImporter.importIfNeeded(into: context, userDefaults: freshDefaults(), configuration: deviceB)

    let groceries = try context.fetchChecklistsSorted().filter { $0.name == "Groceries" }
    XCTAssertEqual(groceries.count, 2, "Same-named checklists from two devices are distinct records.")
    XCTAssertEqual(Set(groceries.flatMap { $0.items.map(\.name) }), ["Milk", "Bread"])
  }

  /// The built-in samples are seeded per device, so two v1.1.0 devices hold *different* records
  /// that merely look alike. If one device's copy has been reset and the other's still has boxes
  /// checked, both are real state and both must survive — merging them would have to pick a device
  /// and silently discard the other's checked boxes.
  ///
  /// Dedupe cannot reach these: it only ever considers records carrying the *fixed* sample ids this
  /// version seeds with, and anything imported from v1.1.0 carries that release's per-device random
  /// id instead.
  @MainActor func testPreSeededSamplesSurviveOnBothDevicesWhenOnlyCheckedStatesDiffer() throws {
    let itemNames = ["START COFFEE MAKER", "Yoga/meditation", "Journaling"]
    // The user reset this list on the iPad, so nothing is checked.
    let deviceA = try writeDeviceStore(named: "iPad", checklists: [("Morning Routine", itemNames)])
    // Same list on the iPhone, still partly checked.
    let deviceB = try writeDeviceStore(
      named: "iPhone",
      checklists: [("Morning Routine", itemNames)],
      checkedItemNames: ["START COFFEE MAKER", "Yoga/meditation"]
    )

    let context = try ModelContext(TestModelContainer.make())
    try LegacyRealmImporter.importIfNeeded(
      into: context, userDefaults: freshDefaults(), configuration: deviceA,
      sortKeyBase: 1 * LegacyRealmImporter.sortKeyBlockSize
    )
    try LegacyRealmImporter.importIfNeeded(
      into: context, userDefaults: freshDefaults(), configuration: deviceB,
      sortKeyBase: 5 * LegacyRealmImporter.sortKeyBlockSize
    )
    try SampleData.dedupeChecklists(in: context)

    let morningRoutines = try context.fetchChecklistsSorted().filter { $0.name == "Morning Routine" }
    XCTAssertEqual(morningRoutines.count, 2, "Both devices' copies are real state and must both survive.")
    XCTAssertEqual(
      morningRoutines.map { checklist in checklist.items.count(where: { $0.status == .checked }) },
      [0, 2],
      "Each copy keeps its own checked states; neither is overwritten by the other."
    )
  }

  // MARK: - Ordering

  /// Each device's list must stay contiguous rather than interleaving with the other's.
  ///
  /// The two bases are pinned here to the two distinct blocks production picks at random; the odds
  /// of a real collision are covered separately below.
  @MainActor func testEachDeviceImportBlockStaysContiguous() throws {
    let deviceA = try writeDeviceStore(named: "iPad", checklists: [("A1", []), ("A2", []), ("A3", [])])
    let deviceB = try writeDeviceStore(named: "iPhone", checklists: [("B1", []), ("B2", []), ("B3", [])])

    let context = try ModelContext(TestModelContainer.make())
    try LegacyRealmImporter.importIfNeeded(
      into: context, userDefaults: freshDefaults(), configuration: deviceA,
      sortKeyBase: 2 * LegacyRealmImporter.sortKeyBlockSize
    )
    try LegacyRealmImporter.importIfNeeded(
      into: context, userDefaults: freshDefaults(), configuration: deviceB,
      sortKeyBase: 7 * LegacyRealmImporter.sortKeyBlockSize
    )

    XCTAssertEqual(
      try context.fetchChecklistsSorted().map(\.name),
      ["A1", "A2", "A3", "B1", "B2", "B3"],
      "Each device's list must be an unbroken run in its original order."
    )
  }

  /// Whichever block sorts lower comes first — the ordering between devices is arbitrary but the
  /// contiguity is not.
  @MainActor func testLowerBlockSortsFirstRegardlessOfImportOrder() throws {
    let deviceA = try writeDeviceStore(named: "iPad", checklists: [("A1", []), ("A2", [])])
    let deviceB = try writeDeviceStore(named: "iPhone", checklists: [("B1", []), ("B2", [])])

    let context = try ModelContext(TestModelContainer.make())
    // B imported first, but lands in the higher block.
    try LegacyRealmImporter.importIfNeeded(
      into: context, userDefaults: freshDefaults(), configuration: deviceB,
      sortKeyBase: 9 * LegacyRealmImporter.sortKeyBlockSize
    )
    try LegacyRealmImporter.importIfNeeded(
      into: context, userDefaults: freshDefaults(), configuration: deviceA,
      sortKeyBase: 1 * LegacyRealmImporter.sortKeyBlockSize
    )

    XCTAssertEqual(try context.fetchChecklistsSorted().map(\.name), ["A1", "A2", "B1", "B2"])
  }

  // MARK: - randomImportSortKeyBase

  /// A block has to be wider than any list that could be imported into it, or two blocks overlap
  /// and the contiguity guarantee above evaporates.
  @MainActor func testBlockIsWiderThanAnyPlausibleChecklistCount() {
    XCTAssertGreaterThan(LegacyRealmImporter.sortKeyBlockSize, 500.0)
  }

  @MainActor func testRandomBaseAlwaysLandsOnABlockBoundaryInRange() {
    let highestBase = Double(LegacyRealmImporter.sortKeyBlockCount - 1) * LegacyRealmImporter.sortKeyBlockSize
    for _ in 0 ..< 200 {
      let base = LegacyRealmImporter.randomImportSortKeyBase()
      XCTAssertGreaterThanOrEqual(base, 0.0)
      XCTAssertLessThanOrEqual(base, highestBase)
      XCTAssertEqual(base.truncatingRemainder(dividingBy: LegacyRealmImporter.sortKeyBlockSize), 0.0)
    }
  }

  /// The scheme is only worth having if it usually separates two devices. Two hundred draws from
  /// ten thousand blocks should collide essentially never.
  @MainActor func testTwoDevicesRarelyLandInTheSameBlock() {
    let draws = (0 ..< 200).map { _ in LegacyRealmImporter.randomImportSortKeyBase() }
    let distinct = Set(draws)
    XCTAssertGreaterThan(
      Double(distinct.count) / Double(draws.count), 0.9,
      "Block collisions should be rare; a collision merely interleaves, but it should not be common."
    )
  }

  /// Keys must stay small enough that `Double` can still subdivide gaps afterwards — the reason
  /// this is a random block rather than a wall-clock timestamp.
  @MainActor func testLargestPossibleBaseStillLeavesRoomForMidpointInsertion() {
    let highestBase = Double(LegacyRealmImporter.sortKeyBlockCount - 1) * LegacyRealmImporter.sortKeyBlockSize
    let first = highestBase + 1.0
    let second = highestBase + 2.0
    let midpoint = SortKeyReorder.key(forInsertingAt: 1, in: [first, second])
    XCTAssertNotNil(midpoint, "Sort keys must remain subdividable at the top of the block range.")
    XCTAssertGreaterThan(try XCTUnwrap(midpoint), first)
    XCTAssertLessThan(try XCTUnwrap(midpoint), second)
  }

  /// The base must leave enough room for midpoint insertion to keep working afterwards.
  @MainActor func testSortKeysRemainSubdividableAfterAnImport() throws {
    let device = try writeDeviceStore(named: "iPad", checklists: [("One", []), ("Two", [])])
    let context = try ModelContext(TestModelContainer.make())
    try LegacyRealmImporter.importIfNeeded(into: context, userDefaults: freshDefaults(), configuration: device)

    let imported = try context.fetchChecklistsSorted()
    let midpoint = try XCTUnwrap(SortKeyReorder.key(forInsertingAt: 1, in: imported.map(\.sortKey)))
    XCTAssertGreaterThan(midpoint, imported[0].sortKey)
    XCTAssertLessThan(midpoint, imported[1].sortKey)
  }
}
