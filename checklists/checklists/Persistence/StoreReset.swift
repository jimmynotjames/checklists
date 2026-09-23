//
//  StoreReset.swift
//  checklists
//

import Foundation

/**
 Deletes every local persistence artifact so the next startup behaves like a first launch.

 The escape hatch behind "Start over fresh" on the container-failure screen: a store that will not
 open cannot be repaired in place, and without this the app is permanently unusable.

 **This destroys data and cannot be undone.** It is only reachable from the failure screen, behind a
 confirmation, and only once the app has already failed to open its store — so there is nothing
 readable left to lose by then. It must never be wired to anything else.

 It deletes the *local* stores only and must never touch iCloud data, so an account holding
 CloudKit records repopulates from them on the next launch; "fresh" is only literally true for
 someone not using iCloud.
 */
enum StoreReset {
  /// Removes the SwiftData store, the legacy Realm store, and the flags recording what has already
  /// happened.
  ///
  /// Best-effort throughout: a file that will not delete is logged and skipped rather than aborting,
  /// because a partial reset still leaves the next launch better off than no reset at all.
  static func startOverFresh(
    storeURL: URL = ProductionContainerFactory.storeURL(),
    realmURL: URL? = LegacyRealmImporter.legacyStoreURL,
    userDefaults: UserDefaults = .standard,
    fileManager: FileManager = .default
  ) {
    AppLog.persistence.warning("storeReset.begin")

    // SwiftData's SQLite store and its write-ahead log and shared-memory sidecars. Leaving a sidecar
    // next to a deleted store is worse than leaving all three, because SQLite may try to recover
    // from an orphaned WAL.
    remove(storeURL, suffixes: ["", "-shm", "-wal"], using: fileManager)

    // Realm's own sidecars, removed through `FileManager` rather than `Realm.deleteFiles(for:)`,
    // which refuses with "already open" if a Realm instance for the file is still alive — possible
    // if the failure was thrown mid-import. Unlinking the paths works regardless.
    if let realmURL {
      remove(realmURL, suffixes: ["", ".lock", ".note", ".management"], using: fileManager)
    }

    // Deliberately asymmetric. The seeding flags are *cleared*, so the next launch seeds the sample
    // checklists rather than opening empty. The import flag is *set*, not cleared: the Realm data
    // is being abandoned on purpose, and if the deletion above failed, clearing this flag would
    // make the next launch re-import the very file that just broke the app, fail the same way, and
    // leave the user in a loop with no way out.
    userDefaults.removeObject(forKey: SampleData.seededFlagKey)
    userDefaults.removeObject(forKey: SampleData.legacyLaunchedAtLeastOnceKey)
    userDefaults.set(true, forKey: LegacyRealmImporter.completedFlagKey)
    // Only read while the import is still needed, which the line above has just ended.
    userDefaults.removeObject(forKey: LegacyRealmImporter.failedAttemptsKey)

    AppLog.persistence.warning("storeReset.complete")
  }

  private static func remove(_ url: URL, suffixes: [String], using fileManager: FileManager) {
    for suffix in suffixes {
      let target = suffix.isEmpty ? url : URL(fileURLWithPath: url.path + suffix)
      guard fileManager.fileExists(atPath: target.path) else { continue }
      do {
        try fileManager.removeItem(at: target)
      } catch {
        let nsError = error as NSError
        AppLog.persistence.error(
          "storeReset.removeFailed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)"
        )
      }
    }
  }
}
