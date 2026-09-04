//
//  LegacyRealmImporter.swift
//  checklists
//

import Foundation
import RealmSwift
import SwiftData

/**
 Copies the user's data out of the old Realm store into SwiftData, exactly once.

 This is not a `SchemaMigrationPlan` stage. Those move data between two versions of *one*
 SwiftData schema; this moves it between two different persistence frameworks, so it is ordinary
 application code that reads one store and writes another.

 Three properties matter, in this order:

 1. **It never loses data.** The Realm file is not deleted, here or anywhere else in this release.
    If anything below goes wrong the original store is still on disk, untouched, and the import
    runs again on the next launch.
 2. **It is idempotent.** Records are matched by their existing `id`, so a second run — after a
    crash, after the completion flag failed to reach disk, after the user tapped Retry — adds
    nothing and changes nothing.
 3. **It verifies before declaring success.** The completion flag is written only after every
    record read out of Realm has been read back out of SwiftData. A partial import leaves the flag
    unset and is retried rather than silently accepted.
 */
enum LegacyRealmImporter {
  /// Set once the copy has completed and been verified.
  static let completedFlagKey = "legacyRealmImportCompletedV1"

  enum ImportError: Error, Equatable {
    /// The copy did not read back intact. Carries counts only — never user content.
    case verificationFailed(expectedChecklists: Int, foundChecklists: Int, expectedItems: Int, foundItems: Int)
  }

  // MARK: - Snapshots

  //
  // Realm objects are live and tied to their store; these plain values are what cross into
  // SwiftData, so no Realm object outlives the read.

  struct ChecklistSnapshot: Equatable {
    let id: String
    let name: String
    let notes: String?
    let items: [ItemSnapshot]
  }

  struct ItemSnapshot: Equatable {
    let id: String
    let name: String
    let notes: String?
    let statusRaw: Int
  }

  // MARK: - Configuration

  /// A configuration limited to the three legacy types.
  ///
  /// Naming the object types explicitly keeps Realm from discovering any other `Object` subclass
  /// that might exist in the binary, so the schema it expects is exactly the schema on disk.
  static func legacyConfiguration(fileURL: URL? = nil) -> Realm.Configuration {
    var configuration = Realm.Configuration.defaultConfiguration
    configuration.objectTypes = [LegacyGroup.self, LegacyChecklist.self, LegacyItem.self]
    if let fileURL {
      configuration.fileURL = fileURL
    }
    return configuration
  }

  static func isNeeded(
    userDefaults: UserDefaults = .standard,
    fileManager: FileManager = .default,
    fileURL: URL? = nil
  ) -> Bool {
    guard !userDefaults.bool(forKey: completedFlagKey) else { return false }
    guard let url = fileURL ?? Realm.Configuration.defaultConfiguration.fileURL else { return false }
    return fileManager.fileExists(atPath: url.path)
  }

  // MARK: - Reading

  /// Reads the legacy store into plain values, in the order the user last saw them.
  ///
  /// Display order came from `LegacyGroup.checklists`, a Realm `List`, so that list is the
  /// authority. Any checklist not reachable through it — which should not exist, but would be
  /// invisible and unrecoverable if dropped — is appended afterwards rather than discarded.
  static func readLegacyChecklists(from configuration: Realm.Configuration = legacyConfiguration()) throws -> [ChecklistSnapshot] {
    let realm = try Realm(configuration: configuration)

    guard let group = realm.objects(LegacyGroup.self).first else {
      // Only reachable from a pre-v1.1.0 install, which predates the Group object entirely.
      // v1.1.0 shipped in 2021, so this is out of scope by decision, not by oversight.
      AppLog.persistence.warning("legacyImport: store has no Group object; nothing to import.")
      return []
    }

    var ordered = Array(group.checklists)
    let linkedIds = Set(ordered.map(\.id))
    let orphans = Array(realm.objects(LegacyChecklist.self)).filter { !linkedIds.contains($0.id) }
    if !orphans.isEmpty {
      AppLog.persistence.warning("legacyImport: \(orphans.count, privacy: .public) checklist(s) not in the Group; appending at the end.")
      ordered.append(contentsOf: orphans)
    }

    return ordered.map { checklist in
      ChecklistSnapshot(
        id: checklist.id,
        name: checklist.name,
        notes: checklist.notes,
        items: Array(checklist.items).map { item in
          ItemSnapshot(id: item.id, name: item.name, notes: item.notes, statusRaw: item.statusRaw)
        }
      )
    }
  }

  // MARK: - Writing

  /// Inserts anything not already present, preserving order as evenly spaced sort keys.
  ///
  /// Matching on `id` is what makes a re-run a no-op. It also means a partially completed earlier
  /// attempt resumes rather than duplicating.
  static func upsert(_ snapshots: [ChecklistSnapshot], into context: ModelContext) throws {
    guard !snapshots.isEmpty else { return }

    var checklistSortKey = SortKeyReorder.step
    for snapshot in snapshots {
      defer { checklistSortKey += SortKeyReorder.step }
      guard context.checklist(id: snapshot.id) == nil else { continue }

      let checklist = Checklist(
        id: snapshot.id,
        name: snapshot.name,
        notes: snapshot.notes,
        sortKey: checklistSortKey
      )
      context.insert(checklist)

      var itemSortKey = SortKeyReorder.step
      for itemSnapshot in snapshot.items {
        let item = Item(
          id: itemSnapshot.id,
          name: itemSnapshot.name,
          notes: itemSnapshot.notes,
          sortKey: itemSortKey
        )
        // Copied raw rather than through `status`, so a value the old build never produced is
        // preserved as-is instead of being silently rewritten to "unchecked".
        item.statusRaw = itemSnapshot.statusRaw
        context.insert(item)
        item.checklist = checklist
        itemSortKey += SortKeyReorder.step
      }
    }

    try context.saveChanges(operation: .legacyImport)
  }

  // MARK: - Orchestration

  static func importIfNeeded(
    into context: ModelContext,
    userDefaults: UserDefaults = .standard,
    fileManager: FileManager = .default,
    configuration: Realm.Configuration = legacyConfiguration()
  ) throws {
    guard isNeeded(userDefaults: userDefaults, fileManager: fileManager, fileURL: configuration.fileURL) else { return }

    let startedAt = Date()
    let snapshots = try readLegacyChecklists(from: configuration)
    try upsert(snapshots, into: context)
    try verify(snapshots, in: context)

    // Written last, and only on the success path: an unset flag costs one harmless repeat run,
    // whereas a flag set too early would skip an import that never actually happened.
    userDefaults.set(true, forKey: completedFlagKey)

    let elapsedMilliseconds = Int(Date().timeIntervalSince(startedAt) * 1000)
    let itemCount = snapshots.reduce(0) { $0 + $1.items.count }
    AppLog.persistence.log(
      "legacyImport.completed: \(snapshots.count, privacy: .public) checklists, \(itemCount, privacy: .public) items, \(elapsedMilliseconds, privacy: .public) ms"
    )
  }

  /// Reads every copied record back out of SwiftData before the import is called done.
  private static func verify(_ snapshots: [ChecklistSnapshot], in context: ModelContext) throws {
    var foundChecklists = 0
    var foundItems = 0

    for snapshot in snapshots {
      guard let checklist = context.checklist(id: snapshot.id) else { continue }
      foundChecklists += 1
      let storedItemIds = Set(checklist.items.map(\.id))
      foundItems += snapshot.items.count(where: { storedItemIds.contains($0.id) })
    }

    let expectedItems = snapshots.reduce(0) { $0 + $1.items.count }
    guard foundChecklists == snapshots.count, foundItems == expectedItems else {
      AppLog.persistence.fault(
        "legacyImport.verificationFailed: checklists \(foundChecklists, privacy: .public)/\(snapshots.count, privacy: .public), items \(foundItems, privacy: .public)/\(expectedItems, privacy: .public)"
      )
      throw ImportError.verificationFailed(
        expectedChecklists: snapshots.count,
        foundChecklists: foundChecklists,
        expectedItems: expectedItems,
        foundItems: foundItems
      )
    }
  }
}
