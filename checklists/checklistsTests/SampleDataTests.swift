//
//  SampleDataTests.swift
//  checklistsTests
//
//  Created by Claude on 8/31/26.
//

@testable import checklists
import RealmSwift
import XCTest

/// Guards the fixture contract that `checklistsUITests` hardcodes: the seeded group, checklist
/// names, and item counts produced by `SampleData.insertFirstTimeLaunchDataV1_1()`. If this file
/// ever needs to change to make these tests pass, the UI test suite needs the matching update —
/// see `SampleData.generateFirstTimeLaunchChecklists()`'s own "also used for automated testing"
/// reminder.
///
/// See the note on `DataModelTests` for why this class is `nonisolated` at the type level with
/// individual `@MainActor` test methods.
/// `@unchecked Sendable`: `MainActor.assumeIsolated` (used in setUp/tearDown below) captures `self`
/// to reach `previousRealm`, and the compiler can't verify that crossing is safe on its own since
/// this class isn't Sendable by default. It genuinely is safe here — XCTest always invokes setUp,
/// every test method, and tearDown on the main thread, serially, for a given instance — so this is
/// the same kind of test-only escape hatch as the class-level `nonisolated` above.
nonisolated final class SampleDataTests: XCTestCase, @unchecked Sendable {
  private var previousRealm: Realm!

  override func setUpWithError() throws {
    try MainActor.assumeIsolated {
      previousRealm = DBManager.realm
      DBManager.realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: "SampleDataTests-\(UUID().uuidString)"))
    }
  }

  override func tearDownWithError() throws {
    MainActor.assumeIsolated {
      DBManager.realm = previousRealm
    }
  }

  @MainActor func testFirstTimeLaunchDataMatchesUITestFixtureContract() {
    SampleData.insertFirstTimeLaunchDataV1_1()

    let groups = DBManager.realm.objects(Group.self)
    XCTAssertEqual(groups.count, 1)
    guard let group = groups.first else { return }

    let checklists = group.checklists
    XCTAssertEqual(checklists.count, 3)

    // `uniquingKeysWith:` rather than `uniqueKeysWithValues:`: the latter traps on a duplicate key,
    // which would abort the whole test process instead of failing this assertion. A duplicate
    // checklist name is exactly the kind of fixture edit this test exists to catch, so it needs to
    // fail cleanly and say so.
    let itemCountsByName = Dictionary(checklists.map { ($0.name, $0.items.count) }, uniquingKeysWith: { first, _ in first })
    XCTAssertEqual(itemCountsByName.count, 3, "Expected three distinctly-named checklists; a duplicate name means the fixture contract changed.")
    XCTAssertEqual(itemCountsByName["Morning Routine"], 6)
    XCTAssertEqual(itemCountsByName["Weekend Getaway Essentials"], 12)
    XCTAssertEqual(itemCountsByName["Pre-Trip Checklist"], 11)
  }

  @MainActor func testClearDatabaseEmptiesEverything() {
    SampleData.insertFirstTimeLaunchDataV1_1()
    XCTAssertGreaterThan(DBManager.realm.objects(Group.self).count, 0)
    XCTAssertGreaterThan(DBManager.realm.objects(Checklist.self).count, 0)
    XCTAssertGreaterThan(DBManager.realm.objects(Item.self).count, 0)

    SampleData.clearDatabase()

    XCTAssertEqual(DBManager.realm.objects(Group.self).count, 0)
    XCTAssertEqual(DBManager.realm.objects(Checklist.self).count, 0)
    XCTAssertEqual(DBManager.realm.objects(Item.self).count, 0)
  }
}
