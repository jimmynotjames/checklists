//
//  SampleDataTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import Testing

/// Covers the first-time-launch fixture in `SampleData.swift`: its exact shape (also the
/// `checklistsUITests` navigation contract), the stability of its fixed ids (the cross-device
/// dedupe contract), idempotent seeding, and `clearDatabase(in:)`.
///
/// `UserDefaults` is isolated per test via a unique suite name, removed when the test's
/// `TestScope.withIsolatedDefaults` scope exits — `.standard` is never touched.
@Suite("SampleData first-launch fixture")
struct SampleDataTests {
  // MARK: - Fixture contract

  @Test("first-time-launch data matches the UI test fixture contract")
  func firstTimeLaunchDataMatchesUITestFixtureContract() throws {
    try TestScope.withIsolatedDefaults("SampleDataTests") { _ in
      let context = try TestModelContainer.makeContext()
      try SampleData.seed(into: context)

      let checklists = try context.fetchChecklistsSorted()
      #expect(checklists.count == 3)

      #expect(checklists.map(\.name) == [
        "Morning Routine",
        "Weekend Getaway Essentials",
        "Pre-Trip Checklist",
      ])
      #expect(checklists.map(\.sortKey) == [1.0, 2.0, 3.0])
      #expect(checklists.map(\.items.count) == [6, 12, 11])

      let checkedCounts = checklists.map { checklist in
        checklist.items.count(where: { $0.status == .checked })
      }
      #expect(checkedCounts == [5, 4, 0])
    }
  }

  // MARK: - Stable ids

  /// These constants are what makes cross-device dedupe possible: two devices signed into the same
  /// iCloud account that each seed themselves before ever syncing must land on the *same* three
  /// record ids, or CloudKit merges four checklists into six instead of three into three. Changing
  /// any of these literals breaks that contract for every install that already seeded itself with
  /// the old value.
  @Test("sample ids are stable")
  func sampleIdsAreStable() throws {
    try TestScope.withIsolatedDefaults("SampleDataTests") { _ in
      #expect(SampleData.morningRoutineId == "C4EC1157-0000-4000-A000-000000000001")
      #expect(SampleData.weekendGetawayId == "C4EC1157-0000-4000-A000-000000000002")
      #expect(SampleData.preTripId == "C4EC1157-0000-4000-A000-000000000003")
    }
  }

  // MARK: - Seeding

  @Test("seeding twice is idempotent")
  func seedIsIdempotent() throws {
    try TestScope.withIsolatedDefaults("SampleDataTests") { userDefaults in
      let context = try TestModelContainer.makeContext()

      try SampleData.insertFirstTimeLaunchDataIfNeeded(into: context, userDefaults: userDefaults)
      try SampleData.insertFirstTimeLaunchDataIfNeeded(into: context, userDefaults: userDefaults)

      #expect(try context.fetchChecklistsSorted().count == 3)
    }
  }

  // MARK: - Clearing

  @Test("clearing the database empties everything")
  func clearDatabaseEmptiesEverything() throws {
    try TestScope.withIsolatedDefaults("SampleDataTests") { _ in
      let context = try TestModelContainer.makeContext()
      try SampleData.seed(into: context)
      #expect(try !(context.fetchChecklistsSorted().isEmpty))

      try SampleData.clearDatabase(in: context)

      #expect(try context.fetch(FetchDescriptor<Checklist>()).isEmpty)
      #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
    }
  }
}
