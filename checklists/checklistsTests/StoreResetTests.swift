//
//  StoreResetTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import RealmSwift
import Testing

/**
 Covers `StoreReset.startOverFresh`, the app's only deliberately destructive operation.

 It is reachable solely from the container-failure screen, behind a confirmation, and only once the
 app has already failed to open its store. These tests pin what it removes and — just as important —
 that it clears the flags recording what has already happened, since leaving those set would hand
 the next launch an empty app that believes it has already imported and seeded.
 */
@Suite("StoreReset.startOverFresh")
struct StoreResetTests {
  /// The per-test fixture: a scratch directory to create store files in, and a `UserDefaults`
  /// on its own suite so a reset's flag clearing can be observed without touching `.standard`.
  private func withFixture(_ body: (URL, UserDefaults) throws -> Void) throws {
    try TestScope.withTemporaryDirectory("store-reset") { directory in
      try TestScope.withIsolatedDefaults("StoreResetTests") { userDefaults in
        try body(directory, userDefaults)
      }
    }
  }

  private func reset(storeURL: URL, realmURL: URL, userDefaults: UserDefaults) {
    StoreReset.startOverFresh(
      storeURL: storeURL,
      realmURL: realmURL,
      userDefaults: userDefaults,
      fileManager: .default
    )
  }

  @Test("removes the store and its SQLite sidecars")
  func removesTheStoreAndItsSqliteSidecars() throws {
    try withFixture { directory, userDefaults in
      let storeURL = directory.appendingPathComponent("default.store")
      let sidecars = ["-shm", "-wal"].map { URL(fileURLWithPath: storeURL.path + $0) }
      for url in [storeURL] + sidecars {
        try Data("stand-in".utf8).write(to: url)
      }

      reset(storeURL: storeURL, realmURL: directory.appendingPathComponent("default.realm"), userDefaults: userDefaults)

      for url in [storeURL] + sidecars {
        #expect(
          !FileManager.default.fileExists(atPath: url.path),
          "An orphaned sidecar is worse than none: SQLite can try to recover from a stray WAL."
        )
      }
    }
  }

  /// Deliberately deletes a Realm that is still open. `Realm.deleteFiles(for:)` refuses in that
  /// state with "already open", and it is entirely possible here: the failure that brought the user
  /// to this screen may have been thrown mid-import with the instance not yet released. Unlinking
  /// the paths has to work anyway, or the recovery path does not recover.
  @Test("removes the legacy Realm store even while it is still open")
  func removesTheLegacyRealmStoreEvenWhileItIsStillOpen() throws {
    try withFixture { directory, userDefaults in
      let realmURL = directory.appendingPathComponent("default.realm")
      let realm = try Realm(configuration: LegacyRealmImporter.legacyConfiguration(fileURL: realmURL))
      try realm.write { realm.add(LegacyGroup()) }
      #expect(FileManager.default.fileExists(atPath: realmURL.path))

      reset(storeURL: directory.appendingPathComponent("default.store"), realmURL: realmURL, userDefaults: userDefaults)

      #expect(!FileManager.default.fileExists(atPath: realmURL.path))
      withExtendedLifetime(realm) {}
    }
  }

  /// The flags matter as much as the files: left set, the next launch would skip both the import
  /// and the first-launch seed and present an empty app.
  @Test("clears the flags that would otherwise skip import and seeding")
  func clearsTheFlagsThatWouldOtherwiseSkipImportAndSeeding() throws {
    try withFixture { directory, userDefaults in
      userDefaults.set(true, forKey: LegacyRealmImporter.completedFlagKey)
      userDefaults.set(true, forKey: SampleData.seededFlagKey)
      userDefaults.set(true, forKey: SampleData.legacyLaunchedAtLeastOnceKey)

      reset(
        storeURL: directory.appendingPathComponent("default.store"),
        realmURL: directory.appendingPathComponent("default.realm"),
        userDefaults: userDefaults
      )

      #expect(!userDefaults.bool(forKey: SampleData.seededFlagKey))
      #expect(!userDefaults.bool(forKey: SampleData.legacyLaunchedAtLeastOnceKey))
    }
  }

  /// The import flag is *set*, not cleared — the opposite of the seeding flags. Clearing it would
  /// send the next launch back to a Realm file that may have survived a failed deletion, to fail
  /// the same way again and trap the user in a loop.
  @Test("marks the legacy import done so it can never run again")
  func marksTheLegacyImportDoneSoItCanNeverRunAgain() throws {
    try withFixture { directory, userDefaults in
      userDefaults.set(false, forKey: LegacyRealmImporter.completedFlagKey)

      reset(
        storeURL: directory.appendingPathComponent("default.store"),
        realmURL: directory.appendingPathComponent("default.realm"),
        userDefaults: userDefaults
      )

      #expect(userDefaults.bool(forKey: LegacyRealmImporter.completedFlagKey))
    }
  }

  /// A data reset is not a consent withdrawal (core-docs/analytics-spec.md §Identity). Silently
  /// re-prompting someone who already declined would be worse than keeping the decision, so
  /// the analytics keys must survive even though everything else in this suite is cleared.
  @Test("does not remove the analytics keys")
  func doesNotRemoveTheAnalyticsKeys() throws {
    try withFixture { directory, userDefaults in
      userDefaults.set(false, forKey: AnalyticsSettings.analyticsOptInKey)
      userDefaults.set("11111111-1111-1111-1111-111111111111", forKey: AnalyticsSettings.analyticsDistinctIdKey)

      reset(
        storeURL: directory.appendingPathComponent("default.store"),
        realmURL: directory.appendingPathComponent("default.realm"),
        userDefaults: userDefaults
      )

      #expect(!userDefaults.bool(forKey: AnalyticsSettings.analyticsOptInKey))
      #expect(
        userDefaults.string(forKey: AnalyticsSettings.analyticsDistinctIdKey)
          == "11111111-1111-1111-1111-111111111111"
      )
    }
  }

  /// The failure it exists for may well be a store that was never created, so absent files must be
  /// a no-op rather than a second failure on top of the first.
  @Test("succeeds when nothing is there to delete")
  func succeedsWhenNothingIsThereToDelete() throws {
    try withFixture { directory, userDefaults in
      reset(
        storeURL: directory.appendingPathComponent("absent.store"),
        realmURL: directory.appendingPathComponent("absent.realm"),
        userDefaults: userDefaults
      )

      #expect(!userDefaults.bool(forKey: SampleData.seededFlagKey))
    }
  }
}
