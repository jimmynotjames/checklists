//
//  SampleDataTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import XCTest

/// Covers the first-time-launch fixture in `SampleData.swift`: its exact shape (also the
/// `checklistsUITests` navigation contract), the stability of its fixed ids (the cross-device
/// dedupe contract), idempotent seeding, and `clearDatabase(in:)`.
///
/// See the doc comment on `DataModelTests` for why this class is `nonisolated` at the type level
/// with individual `@MainActor` test methods.
///
/// `UserDefaults` is isolated per test via a unique suite name, removed in `tearDown` — `.standard`
/// is never touched.
nonisolated final class SampleDataTests: XCTestCase {
  private var suiteName: String!
  private var userDefaults: UserDefaults!

  override func setUpWithError() throws {
    try super.setUpWithError()
    suiteName = "SampleDataTests-\(UUID().uuidString)"
    userDefaults = UserDefaults(suiteName: suiteName)
  }

  override func tearDownWithError() throws {
    userDefaults.removePersistentDomain(forName: suiteName)
    userDefaults = nil
    suiteName = nil
    try super.tearDownWithError()
  }

  @MainActor private func makeContext() throws -> ModelContext {
    try ModelContext(TestModelContainer.make())
  }

  // MARK: - Fixture contract

  @MainActor func testFirstTimeLaunchDataMatchesUITestFixtureContract() throws {
    let context = try makeContext()
    try SampleData.seed(into: context)

    let checklists = try context.fetchChecklistsSorted()
    XCTAssertEqual(checklists.count, 3)

    XCTAssertEqual(checklists.map(\.name), [
      "Morning Routine",
      "Weekend Getaway Essentials",
      "Pre-Trip Checklist",
    ])
    XCTAssertEqual(checklists.map(\.sortKey), [1.0, 2.0, 3.0])
    XCTAssertEqual(checklists.map(\.items.count), [6, 12, 11])

    let checkedCounts = checklists.map { checklist in
      checklist.items.count(where: { $0.status == .checked })
    }
    XCTAssertEqual(checkedCounts, [5, 4, 0])
  }

  // MARK: - Stable ids

  /// These constants are what makes cross-device dedupe possible: two devices signed into the same
  /// iCloud account that each seed themselves before ever syncing must land on the *same* three
  /// record ids, or CloudKit merges four checklists into six instead of three into three. Changing
  /// any of these literals breaks that contract for every install that already seeded itself with
  /// the old value.
  @MainActor func testSampleIdsAreStable() {
    XCTAssertEqual(SampleData.morningRoutineId, "C4EC1157-0000-4000-A000-000000000001")
    XCTAssertEqual(SampleData.weekendGetawayId, "C4EC1157-0000-4000-A000-000000000002")
    XCTAssertEqual(SampleData.preTripId, "C4EC1157-0000-4000-A000-000000000003")
  }

  // MARK: - Seeding

  @MainActor func testSeedIsIdempotent() throws {
    let context = try makeContext()

    try SampleData.insertFirstTimeLaunchDataIfNeeded(into: context, userDefaults: userDefaults)
    try SampleData.insertFirstTimeLaunchDataIfNeeded(into: context, userDefaults: userDefaults)

    XCTAssertEqual(try context.fetchChecklistsSorted().count, 3)
  }

  // MARK: - Clearing

  @MainActor func testClearDatabaseEmptiesEverything() throws {
    let context = try makeContext()
    try SampleData.seed(into: context)
    XCTAssertFalse(try context.fetchChecklistsSorted().isEmpty)

    try SampleData.clearDatabase(in: context)

    XCTAssertTrue(try context.fetch(FetchDescriptor<Checklist>()).isEmpty)
    XCTAssertTrue(try context.fetch(FetchDescriptor<Item>()).isEmpty)
  }
}
