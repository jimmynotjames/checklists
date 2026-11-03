//
//  LegacyRealmImporterTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import RealmSwift
import SwiftData
import Testing

private struct FixtureItem {
  let name: String
  var notes: String?
  var statusRaw: Int = 0
}

private struct FixtureChecklist {
  let name: String
  var notes: String?
  var items: [FixtureItem] = []
}

/**
 Covers the one-time copy out of the old Realm store — the only code path in the app that can lose
 a user's data, and the one that runs exactly once on a device we will never see.

 Each test builds a real, v1.1.0-shaped Realm fixture (`LegacyGroup`/`LegacyChecklist`/`LegacyItem`) and imports it into an in-memory SwiftData container.
 */
@Suite("Legacy Realm import")
struct LegacyRealmImporterTests {
  /// The per-test fixture: a scratch directory holding the legacy `default.realm` the importer
  /// reads, plus a `UserDefaults` on its own suite so the completion flag can be observed
  /// without touching `.standard`.
  private func withFixture(_ body: (URL, UserDefaults) throws -> Void) throws {
    try TestScope.withTemporaryDirectory("legacy-realm") { directory in
      try TestScope.withIsolatedDefaults("LegacyRealmImporterTests") { userDefaults in
        try body(directory.appendingPathComponent("default.realm"), userDefaults)
      }
    }
  }

  // MARK: - Helpers

  private func legacyConfiguration(fixtureURL: URL) -> Realm.Configuration {
    LegacyRealmImporter.legacyConfiguration(fileURL: fixtureURL)
  }

  /// Writes a fixture in the v1.1.0 shape: one `Group` holding checklists in display order.
  ///
  /// - Parameter unlinkedChecklistNames: checklists written to the file but deliberately left out
  ///   of the `Group`, to stand in for a store that lost its ordering link.
  private func writeFixture(
    fixtureURL: URL,
    checklists: [FixtureChecklist],
    unlinkedChecklistNames: [String] = [],
    includeGroup: Bool = true,
  ) throws {
    let realm = try Realm(configuration: legacyConfiguration(fixtureURL: fixtureURL))
    try realm.write {
      let group = LegacyGroup()
      for checklist in checklists {
        let legacyChecklist = LegacyChecklist()
        legacyChecklist.name = checklist.name
        legacyChecklist.notes = checklist.notes
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
        // Still persist the checklists themselves, so the file holds them with no `Group` to
        // reach them through.
        for checklist in group.checklists {
          realm.add(checklist)
        }
      }
    }
  }

  private func runImport(
    into context: ModelContext,
    fixtureURL: URL,
    userDefaults: UserDefaults,
    analytics: any AnalyticsClient = ConsoleAnalyticsClient(),
  ) throws {
    try LegacyRealmImporter.importIfNeeded(
      into: context,
      userDefaults: userDefaults,
      configuration: legacyConfiguration(fixtureURL: fixtureURL),
      analytics: analytics,
    )
  }

  // MARK: - Schema pinning

  /// The Swift types were renamed to `Legacy*` so `Checklist` and `Item` could be reused by the
  /// SwiftData models. Realm names its tables after the Objective-C runtime name, so each class
  /// carries an `@objc(...)` attribute to keep the on-disk names as they shipped. If this fails,
  /// every existing user's store has become unreadable.
  @Test("legacy class names match the shipped schema")
  func legacyClassNamesMatchTheShippedSchema() {
    #expect(LegacyGroup.className() == "Group")
    #expect(LegacyChecklist.className() == "Checklist")
    #expect(LegacyItem.className() == "Item")
  }

  // MARK: - Ordering and content

  @Test("import preserves checklist order from the group")
  func importPreservesChecklistOrderFromTheGroup() throws {
    try withFixture { fixtureURL, userDefaults in
      try writeFixture(fixtureURL: fixtureURL, checklists: [
        FixtureChecklist(name: "Groceries"),
        FixtureChecklist(name: "Packing", notes: "for the trip"),
        FixtureChecklist(name: "Chores"),
      ])
      let context = try TestModelContainer.makeContext()

      try runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults)

      let imported = try context.fetchChecklistsSorted()
      #expect(imported.map(\.name) == ["Groceries", "Packing", "Chores"])
      #expect(imported[1].notes == "for the trip")
      #expect(imported[0].notes == nil)
    }
  }

  @Test("import preserves item order, notes, and statuses")
  func importPreservesItemOrderNotesAndStatuses() throws {
    try withFixture { fixtureURL, userDefaults in
      try writeFixture(fixtureURL: fixtureURL, checklists: [
        FixtureChecklist(name: "Packing", items: [
          FixtureItem(name: "Passport", notes: "in the drawer", statusRaw: 1),
          FixtureItem(name: "Charger"),
          FixtureItem(name: "Tickets", statusRaw: 1),
        ]),
      ])
      let context = try TestModelContainer.makeContext()

      try runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults)

      let checklist = try #require(context.fetchChecklistsSorted().first)
      #expect(checklist.items.map(\.name) == ["Passport", "Charger", "Tickets"])
      #expect(checklist.items.map(\.status) == [.checked, .unchecked, .checked])
      #expect(checklist.items[0].notes == "in the drawer")
      #expect(checklist.items[1].notes == nil)
    }
  }

  /// Sort keys have to be distinct and ascending, or the order above is luck rather than data.
  @Test("import assigns ascending sort keys")
  func importAssignsAscendingSortKeys() throws {
    try withFixture { fixtureURL, userDefaults in
      try writeFixture(fixtureURL: fixtureURL, checklists: [
        FixtureChecklist(name: "One", items: [FixtureItem(name: "a"), FixtureItem(name: "b")]),
        FixtureChecklist(name: "Two"),
      ])
      let context = try TestModelContainer.makeContext()

      try runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults)

      let imported = try context.fetchChecklistsSorted()
      // Checklist keys are relative to a random per-import block (see `randomImportSortKeyBase`), so
      // assert the spacing rather than absolute values.
      #expect(imported.count == 2)
      #expect(imported[1].sortKey - imported[0].sortKey == SortKeyReorder.step)
      #expect(imported[0].sortKey >= SortKeyReorder.step)
      // Items are scoped to one checklist from one device, so they always start at 1.0.
      #expect(imported[0].items.map(\.sortKey) == [1.0, 2.0])
    }
  }

  /// Relationship wiring: items must come back through the parent, not just exist.
  @Test("imported items are linked to their checklist")
  func importedItemsAreLinkedToTheirChecklist() throws {
    try withFixture { fixtureURL, userDefaults in
      try writeFixture(fixtureURL: fixtureURL, checklists: [
        FixtureChecklist(name: "One", items: [FixtureItem(name: "a")]),
        FixtureChecklist(name: "Two", items: [FixtureItem(name: "b")]),
      ])
      let context = try TestModelContainer.makeContext()

      try runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults)

      let imported = try context.fetchChecklistsSorted()
      #expect(imported[0].items.map(\.name) == ["a"])
      #expect(imported[1].items.map(\.name) == ["b"])
      #expect(imported[0].items.first?.checklist?.name == "One")
    }
  }

  @Test("checklists missing from the group are appended rather than dropped")
  func checklistsMissingFromTheGroupAreAppendedRatherThanDropped() throws {
    try withFixture { fixtureURL, userDefaults in
      try writeFixture(
        fixtureURL: fixtureURL,
        checklists: [FixtureChecklist(name: "Linked")],
        unlinkedChecklistNames: ["Orphan"],
      )
      let context = try TestModelContainer.makeContext()

      try runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults)

      #expect(try context.fetchChecklistsSorted().map(\.name) == ["Linked", "Orphan"])
    }
  }

  // MARK: - Idempotency and the completion flag

  @Test("running the import a second time changes nothing")
  func secondRunChangesNothing() throws {
    try withFixture { fixtureURL, userDefaults in
      try writeFixture(fixtureURL: fixtureURL, checklists: [
        FixtureChecklist(name: "Packing", items: [FixtureItem(name: "Passport", statusRaw: 1)]),
      ])
      let context = try TestModelContainer.makeContext()
      try runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults)

      // Clearing the flag forces the work to run a second time, standing in for a crash between the
      // save and the flag reaching disk.
      userDefaults.set(false, forKey: LegacyRealmImporter.completedFlagKey)
      try runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults)

      let imported = try context.fetchChecklistsSorted()
      #expect(imported.count == 1)
      #expect(imported.first?.items.count == 1)
    }
  }

  @Test("a successful import sets the completion flag")
  func successfulImportSetsTheCompletionFlag() throws {
    try withFixture { fixtureURL, userDefaults in
      try writeFixture(fixtureURL: fixtureURL, checklists: [FixtureChecklist(name: "Packing")])
      let context = try TestModelContainer.makeContext()

      try runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults)

      #expect(userDefaults.bool(forKey: LegacyRealmImporter.completedFlagKey))
      #expect(!LegacyRealmImporter.isNeeded(userDefaults: userDefaults, fileURL: fixtureURL))
    }
  }

  /// A failed import must stay pending. Setting the flag on the way in would turn one bad launch
  /// into permanent data loss, because the Realm file would never be read again.
  @Test("a failed import leaves the flag unset so it retries")
  func failedImportLeavesTheFlagUnsetSoItRetries() throws {
    try withFixture { fixtureURL, userDefaults in
      try Data("not a realm file".utf8).write(to: fixtureURL)
      let context = try TestModelContainer.makeContext()

      #expect(throws: (any Error).self) { try runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults) }

      #expect(!userDefaults.bool(forKey: LegacyRealmImporter.completedFlagKey))
      #expect(LegacyRealmImporter.isNeeded(userDefaults: userDefaults, fileURL: fixtureURL))
    }
  }

  /// Every precondition `isNeeded` checks is still true after a failure, so a durable cause — a
  /// corrupt file, most likely — fails identically forever. Without a ceiling the user never
  /// reaches the app at all, and the escape that used to exist deleted the very file at stake.
  @Test("a repeatedly failing import is abandoned rather than retried forever")
  func repeatedlyFailingImportIsAbandoned() throws {
    try withFixture { fixtureURL, userDefaults in
      try Data("not a realm file".utf8).write(to: fixtureURL)
      let context = try TestModelContainer.makeContext()
      let spy = SpyAnalyticsClient()

      for attempt in 1 ..< LegacyRealmImporter.maximumAttempts {
        #expect(throws: (any Error).self) {
          try runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults, analytics: spy)
        }
        #expect(!userDefaults.bool(forKey: LegacyRealmImporter.completedFlagKey), "Gave up on attempt \(attempt).")
      }

      // The attempt that gives up returns instead of throwing, so the app opens.
      try runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults, analytics: spy)

      #expect(userDefaults.bool(forKey: LegacyRealmImporter.completedFlagKey))
      #expect(!LegacyRealmImporter.isNeeded(userDefaults: userDefaults, fileURL: fixtureURL))
      #expect(spy.count(of: AnalyticsEvent.legacyImportAbandoned) == 1)
    }
  }

  @Test("abandoning the import keeps the Realm file on disk")
  func abandoningTheImportKeepsTheRealmFile() throws {
    try withFixture { fixtureURL, userDefaults in
      try Data("not a realm file".utf8).write(to: fixtureURL)
      let context = try TestModelContainer.makeContext()

      for _ in 0 ..< LegacyRealmImporter.maximumAttempts {
        try? runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults)
      }

      #expect(FileManager.default.fileExists(atPath: fixtureURL.path))
    }
  }

  /// The counter records consecutive failures, not lifetime ones — a success has to clear it, or a
  /// user who recovered once would be abandoned early on some unrelated failure much later.
  @Test("a successful import clears the failed-attempt count")
  func successfulImportClearsTheAttemptCount() throws {
    try withFixture { fixtureURL, userDefaults in
      userDefaults.set(LegacyRealmImporter.maximumAttempts - 1, forKey: LegacyRealmImporter.failedAttemptsKey)
      try writeFixture(fixtureURL: fixtureURL, checklists: [FixtureChecklist(name: "Packing")])
      let context = try TestModelContainer.makeContext()

      try runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults)

      #expect(userDefaults.object(forKey: LegacyRealmImporter.failedAttemptsKey) == nil)
    }
  }

  /// With no `Group` there is no display order to follow, but every checklist is still reachable
  /// as an orphan: the import runs once and never reads the Realm file again, so anything it skips
  /// here is gone permanently.
  @Test("a store with no group imports every checklist")
  func storeWithNoGroupImportsEveryChecklist() throws {
    try withFixture { fixtureURL, userDefaults in
      try writeFixture(
        fixtureURL: fixtureURL,
        checklists: [
          FixtureChecklist(name: "Packing", items: [FixtureItem(name: "Passport")]),
          FixtureChecklist(name: "Groceries"),
        ],
        includeGroup: false,
      )
      let context = try TestModelContainer.makeContext()

      try runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults)

      let imported = try context.fetchChecklistsSorted()
      #expect(Set(imported.map(\.name)) == ["Packing", "Groceries"])
      #expect(imported.first { $0.name == "Packing" }?.items.map(\.name) == ["Passport"])
      #expect(userDefaults.bool(forKey: LegacyRealmImporter.completedFlagKey))
    }
  }

  @Test("an empty store imports nothing but still completes")
  func emptyStoreImportsNothingButStillCompletes() throws {
    try withFixture { fixtureURL, userDefaults in
      try writeFixture(fixtureURL: fixtureURL, checklists: [])
      let context = try TestModelContainer.makeContext()

      try runImport(into: context, fixtureURL: fixtureURL, userDefaults: userDefaults)

      #expect(try context.fetchChecklistsSorted().isEmpty)
      #expect(userDefaults.bool(forKey: LegacyRealmImporter.completedFlagKey))
    }
  }

  // MARK: - isNeeded

  @Test("import is not needed when no legacy file exists")
  func importIsNotNeededWhenNoLegacyFileExists() throws {
    try withFixture { fixtureURL, userDefaults in
      let missing = fixtureURL.deletingLastPathComponent().appendingPathComponent("absent.realm")
      #expect(!LegacyRealmImporter.isNeeded(userDefaults: userDefaults, fileURL: missing))
    }
  }

  @Test("import is not needed once the flag is set")
  func importIsNotNeededOnceTheFlagIsSet() throws {
    try withFixture { fixtureURL, userDefaults in
      try writeFixture(fixtureURL: fixtureURL, checklists: [])
      userDefaults.set(true, forKey: LegacyRealmImporter.completedFlagKey)
      #expect(!LegacyRealmImporter.isNeeded(userDefaults: userDefaults, fileURL: fixtureURL))
    }
  }
}
