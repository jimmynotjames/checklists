//
//  LegacyRealmImporterTests.swift
//  checklistsTests
//

@testable import checklists
import RealmSwift
import SwiftData
import XCTest

/**
 Covers the one-time copy out of the old Realm store — the only code path in the app that can lose
 a user's data, and the one that runs exactly once on a device we will never see.

 Each test builds a real Realm file in the test process's temporary directory, in the same shape
 v1.1.0 wrote, then imports it into an in-memory SwiftData container. The fixture is written
 through `LegacyGroup`/`LegacyChecklist`/`LegacyItem`, so these tests would also catch those
 declarations drifting away from the shipped schema.

 See the doc comment on `DataModelTests` for why this class — and every other `XCTestCase`
 subclass in this target — is `nonisolated` at the type level with individual `@MainActor` test
 methods and helpers.
 */
private struct FixtureItem {
  let name: String
  var notes: String?
  var statusRaw: Int = 0
}

private struct FixtureChecklist {
  let name: String
  var notes: String?
  var items: [FixtureItem] = []
  /// Only meaningful for the pre-v1.1.0 (no-`Group`) fixtures, where it is the ordering field.
  var sortNumber: Double = 0.0
}

nonisolated final class LegacyRealmImporterTests: XCTestCase {
  private var fixtureDirectory: URL!
  private var fixtureURL: URL!
  private var suiteName: String!
  private var userDefaults: UserDefaults!

  override func setUpWithError() throws {
    try super.setUpWithError()
    fixtureDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("legacy-realm-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
    fixtureURL = fixtureDirectory.appendingPathComponent("default.realm")

    suiteName = "LegacyRealmImporterTests-\(UUID().uuidString)"
    userDefaults = UserDefaults(suiteName: suiteName)
  }

  override func tearDownWithError() throws {
    userDefaults.removePersistentDomain(forName: suiteName)
    userDefaults = nil
    try? FileManager.default.removeItem(at: fixtureDirectory)
    fixtureDirectory = nil
    fixtureURL = nil
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  @MainActor private func legacyConfiguration() -> Realm.Configuration {
    LegacyRealmImporter.legacyConfiguration(fileURL: fixtureURL)
  }

  /// Writes a fixture in the v1.1.0 shape: one `Group` holding checklists in display order.
  ///
  /// - Parameter unlinkedChecklistNames: checklists written to the file but deliberately left out
  ///   of the `Group`, to stand in for a store that lost its ordering link.
  @MainActor private func writeFixture(
    checklists: [FixtureChecklist],
    unlinkedChecklistNames: [String] = [],
    includeGroup: Bool = true
  ) throws {
    let realm = try Realm(configuration: legacyConfiguration())
    try realm.write {
      let group = LegacyGroup()
      for checklist in checklists {
        let legacyChecklist = LegacyChecklist()
        legacyChecklist.name = checklist.name
        legacyChecklist.notes = checklist.notes
        legacyChecklist.sortNumber = checklist.sortNumber
        for item in checklist.items {
          let legacyItem = LegacyItem()
          legacyItem.name = item.name
          legacyItem.notes = item.notes
          legacyItem.statusRaw = item.statusRaw
          legacyChecklist.items.append(legacyItem)
        }
        group.checklists.append(legacyChecklist)
      }
      for name in unlinkedChecklistNames {
        let orphan = LegacyChecklist()
        orphan.name = name
        realm.add(orphan)
      }
      if includeGroup {
        realm.add(group)
      } else {
        // Still persist the checklists themselves, so the file is non-empty exactly as a
        // pre-v1.1.0 store would be.
        for checklist in group.checklists {
          realm.add(checklist)
        }
      }
    }
  }

  @MainActor private func makeContext() throws -> ModelContext {
    try ModelContext(TestModelContainer.make())
  }

  @MainActor private func runImport(into context: ModelContext) throws {
    try LegacyRealmImporter.importIfNeeded(
      into: context,
      userDefaults: userDefaults,
      configuration: legacyConfiguration()
    )
  }

  // MARK: - Schema pinning

  /// The Swift types were renamed to `Legacy*` so `Checklist` and `Item` could be reused by the
  /// SwiftData models. Realm names its tables after the Objective-C runtime name, so each class
  /// carries an `@objc(...)` attribute to keep the on-disk names as they shipped. If this fails,
  /// every existing user's store has become unreadable.
  @MainActor func testLegacyClassNamesMatchTheShippedSchema() {
    XCTAssertEqual(LegacyGroup.className(), "Group")
    XCTAssertEqual(LegacyChecklist.className(), "Checklist")
    XCTAssertEqual(LegacyItem.className(), "Item")
  }

  // MARK: - Ordering and content

  @MainActor func testImportPreservesChecklistOrderFromTheGroup() throws {
    try writeFixture(checklists: [
      FixtureChecklist(name: "Groceries"),
      FixtureChecklist(name: "Packing", notes: "for the trip"),
      FixtureChecklist(name: "Chores"),
    ])
    let context = try makeContext()

    try runImport(into: context)

    let imported = try context.fetchChecklistsSorted()
    XCTAssertEqual(imported.map(\.name), ["Groceries", "Packing", "Chores"])
    XCTAssertEqual(imported[1].notes, "for the trip")
    XCTAssertNil(imported[0].notes)
  }

  @MainActor func testImportPreservesItemOrderNotesAndStatuses() throws {
    try writeFixture(checklists: [
      FixtureChecklist(name: "Packing", items: [
        FixtureItem(name: "Passport", notes: "in the drawer", statusRaw: 1),
        FixtureItem(name: "Charger"),
        FixtureItem(name: "Tickets", statusRaw: 1),
      ]),
    ])
    let context = try makeContext()

    try runImport(into: context)

    let checklist = try XCTUnwrap(try context.fetchChecklistsSorted().first)
    XCTAssertEqual(checklist.items.map(\.name), ["Passport", "Charger", "Tickets"])
    XCTAssertEqual(checklist.items.map(\.status), [.checked, .unchecked, .checked])
    XCTAssertEqual(checklist.items[0].notes, "in the drawer")
    XCTAssertNil(checklist.items[1].notes)
  }

  /// Sort keys have to be distinct and ascending, or the order above is luck rather than data.
  @MainActor func testImportAssignsAscendingSortKeys() throws {
    try writeFixture(checklists: [
      FixtureChecklist(name: "One", items: [FixtureItem(name: "a"), FixtureItem(name: "b")]),
      FixtureChecklist(name: "Two"),
    ])
    let context = try makeContext()

    try runImport(into: context)

    let imported = try context.fetchChecklistsSorted()
    // Checklist keys are relative to a random per-import block (see `randomImportSortKeyBase`), so
    // assert the spacing rather than absolute values.
    XCTAssertEqual(imported.count, 2)
    XCTAssertEqual(imported[1].sortKey - imported[0].sortKey, SortKeyReorder.step)
    XCTAssertGreaterThanOrEqual(imported[0].sortKey, SortKeyReorder.step)
    // Items are scoped to one checklist from one device, so they always start at 1.0.
    XCTAssertEqual(imported[0].items.map(\.sortKey), [1.0, 2.0])
  }

  /// Relationship wiring: items must come back through the parent, not just exist.
  @MainActor func testImportedItemsAreLinkedToTheirChecklist() throws {
    try writeFixture(checklists: [
      FixtureChecklist(name: "One", items: [FixtureItem(name: "a")]),
      FixtureChecklist(name: "Two", items: [FixtureItem(name: "b")]),
    ])
    let context = try makeContext()

    try runImport(into: context)

    let imported = try context.fetchChecklistsSorted()
    XCTAssertEqual(imported[0].items.map(\.name), ["a"])
    XCTAssertEqual(imported[1].items.map(\.name), ["b"])
    XCTAssertEqual(imported[0].items.first?.checklist?.name, "One")
  }

  @MainActor func testChecklistsMissingFromTheGroupAreAppendedRatherThanDropped() throws {
    try writeFixture(
      checklists: [FixtureChecklist(name: "Linked")],
      unlinkedChecklistNames: ["Orphan"]
    )
    let context = try makeContext()

    try runImport(into: context)

    XCTAssertEqual(try context.fetchChecklistsSorted().map(\.name), ["Linked", "Orphan"])
  }

  // MARK: - Idempotency and the completion flag

  @MainActor func testSecondRunChangesNothing() throws {
    try writeFixture(checklists: [
      FixtureChecklist(name: "Packing", items: [FixtureItem(name: "Passport", statusRaw: 1)]),
    ])
    let context = try makeContext()
    try runImport(into: context)

    // Clearing the flag forces the work to run a second time, standing in for a crash between the
    // save and the flag reaching disk.
    userDefaults.set(false, forKey: LegacyRealmImporter.completedFlagKey)
    try runImport(into: context)

    let imported = try context.fetchChecklistsSorted()
    XCTAssertEqual(imported.count, 1)
    XCTAssertEqual(imported.first?.items.count, 1)
  }

  @MainActor func testSuccessfulImportSetsTheCompletionFlag() throws {
    try writeFixture(checklists: [FixtureChecklist(name: "Packing")])
    let context = try makeContext()

    try runImport(into: context)

    XCTAssertTrue(userDefaults.bool(forKey: LegacyRealmImporter.completedFlagKey))
    XCTAssertFalse(LegacyRealmImporter.isNeeded(userDefaults: userDefaults, fileURL: fixtureURL))
  }

  /// A failed import must stay pending. Setting the flag on the way in would turn one bad launch
  /// into permanent data loss, because the Realm file would never be read again.
  @MainActor func testFailedImportLeavesTheFlagUnsetSoItRetries() throws {
    try Data("not a realm file".utf8).write(to: fixtureURL)
    let context = try makeContext()

    XCTAssertThrowsError(try runImport(into: context))

    XCTAssertFalse(userDefaults.bool(forKey: LegacyRealmImporter.completedFlagKey))
    XCTAssertTrue(LegacyRealmImporter.isNeeded(userDefaults: userDefaults, fileURL: fixtureURL))
  }

  /// A store with no `Group` was written before v1.1.0, which ordered checklists by `sortNumber`.
  /// Upgrading straight from that release is not a supported path, but the import still has to
  /// carry the data across: it runs once and then never reads the Realm file again, so anything it
  /// skips here is gone permanently.
  @MainActor func testStoreWithNoGroupRecoversChecklistsBySortNumber() throws {
    try writeFixture(
      checklists: [
        FixtureChecklist(name: "Third", sortNumber: 3.0),
        FixtureChecklist(name: "First", items: [FixtureItem(name: "a")], sortNumber: 1.0),
        FixtureChecklist(name: "Second", sortNumber: 2.0),
      ],
      includeGroup: false
    )
    let context = try makeContext()

    try runImport(into: context)

    let imported = try context.fetchChecklistsSorted()
    XCTAssertEqual(imported.map(\.name), ["First", "Second", "Third"])
    XCTAssertEqual(imported.first?.items.map(\.name), ["a"])
    XCTAssertTrue(userDefaults.bool(forKey: LegacyRealmImporter.completedFlagKey))
  }

  @MainActor func testEmptyStoreImportsNothingButStillCompletes() throws {
    try writeFixture(checklists: [])
    let context = try makeContext()

    try runImport(into: context)

    XCTAssertEqual(try context.fetchChecklistsSorted().count, 0)
    XCTAssertTrue(userDefaults.bool(forKey: LegacyRealmImporter.completedFlagKey))
  }

  // MARK: - isNeeded

  @MainActor func testImportIsNotNeededWhenNoLegacyFileExists() {
    let missing = fixtureDirectory.appendingPathComponent("absent.realm")
    XCTAssertFalse(LegacyRealmImporter.isNeeded(userDefaults: userDefaults, fileURL: missing))
  }

  @MainActor func testImportIsNotNeededOnceTheFlagIsSet() throws {
    try writeFixture(checklists: [])
    userDefaults.set(true, forKey: LegacyRealmImporter.completedFlagKey)
    XCTAssertFalse(LegacyRealmImporter.isNeeded(userDefaults: userDefaults, fileURL: fixtureURL))
  }
}
