//
//  StoreResetTests.swift
//  checklistsTests
//

@testable import checklists
import RealmSwift
import XCTest

/**
 Covers `StoreReset.startOverFresh`, the app's only deliberately destructive operation.

 It is reachable solely from the container-failure screen, behind a confirmation, and only once the
 app has already failed to open its store. These tests pin what it removes and — just as important —
 that it clears the flags recording what has already happened, since leaving those set would hand
 the next launch an empty app that believes it has already imported and seeded.

 See the doc comment on `DataModelTests` for why this class is `nonisolated` at the type level with
 individual `@MainActor` test methods.
 */
nonisolated final class StoreResetTests: XCTestCase {
  private var directory: URL!
  private var suiteName: String!
  private var userDefaults: UserDefaults!

  override func setUpWithError() throws {
    try super.setUpWithError()
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("store-reset-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    suiteName = "StoreResetTests-\(UUID().uuidString)"
    userDefaults = UserDefaults(suiteName: suiteName)
  }

  override func tearDownWithError() throws {
    userDefaults.removePersistentDomain(forName: suiteName)
    userDefaults = nil
    try? FileManager.default.removeItem(at: directory)
    directory = nil
    try super.tearDownWithError()
  }

  @MainActor private func reset(storeURL: URL, realmURL: URL) {
    StoreReset.startOverFresh(
      storeURL: storeURL,
      realmURL: realmURL,
      userDefaults: userDefaults,
      fileManager: .default
    )
  }

  @MainActor func testRemovesTheStoreAndItsSqliteSidecars() throws {
    let storeURL = directory.appendingPathComponent("default.store")
    let sidecars = ["-shm", "-wal"].map { URL(fileURLWithPath: storeURL.path + $0) }
    for url in [storeURL] + sidecars {
      try Data("stand-in".utf8).write(to: url)
    }

    reset(storeURL: storeURL, realmURL: directory.appendingPathComponent("default.realm"))

    for url in [storeURL] + sidecars {
      XCTAssertFalse(
        FileManager.default.fileExists(atPath: url.path),
        "An orphaned sidecar is worse than none: SQLite can try to recover from a stray WAL."
      )
    }
  }

  /// Deliberately deletes a Realm that is still open. `Realm.deleteFiles(for:)` refuses in that
  /// state with "already open", and it is entirely possible here: the failure that brought the user
  /// to this screen may have been thrown mid-import with the instance not yet released. Unlinking
  /// the paths has to work anyway, or the recovery path does not recover.
  @MainActor func testRemovesTheLegacyRealmStoreEvenWhileItIsStillOpen() throws {
    let realmURL = directory.appendingPathComponent("default.realm")
    let realm = try Realm(configuration: LegacyRealmImporter.legacyConfiguration(fileURL: realmURL))
    try realm.write { realm.add(LegacyGroup()) }
    XCTAssertTrue(FileManager.default.fileExists(atPath: realmURL.path))

    reset(storeURL: directory.appendingPathComponent("default.store"), realmURL: realmURL)

    XCTAssertFalse(FileManager.default.fileExists(atPath: realmURL.path))
    withExtendedLifetime(realm) {}
  }

  /// The flags matter as much as the files: left set, the next launch would skip both the import
  /// and the first-launch seed and present an empty app.
  @MainActor func testClearsTheFlagsThatWouldOtherwiseSkipImportAndSeeding() {
    userDefaults.set(true, forKey: LegacyRealmImporter.completedFlagKey)
    userDefaults.set(true, forKey: SampleData.seededFlagKey)
    userDefaults.set(true, forKey: SampleData.legacyLaunchedAtLeastOnceKey)

    reset(
      storeURL: directory.appendingPathComponent("default.store"),
      realmURL: directory.appendingPathComponent("default.realm")
    )

    XCTAssertFalse(userDefaults.bool(forKey: SampleData.seededFlagKey))
    XCTAssertFalse(userDefaults.bool(forKey: SampleData.legacyLaunchedAtLeastOnceKey))
  }

  /// The import flag is *set*, not cleared — the opposite of the seeding flags. Clearing it would
  /// send the next launch back to a Realm file that may have survived a failed deletion, to fail
  /// the same way again and trap the user in a loop.
  @MainActor func testMarksTheLegacyImportDoneSoItCanNeverRunAgain() {
    userDefaults.set(false, forKey: LegacyRealmImporter.completedFlagKey)

    reset(
      storeURL: directory.appendingPathComponent("default.store"),
      realmURL: directory.appendingPathComponent("default.realm")
    )

    XCTAssertTrue(userDefaults.bool(forKey: LegacyRealmImporter.completedFlagKey))
  }

  /// The failure it exists for may well be a store that was never created, so absent files must be
  /// a no-op rather than a second failure on top of the first.
  @MainActor func testSucceedsWhenNothingIsThereToDelete() {
    reset(
      storeURL: directory.appendingPathComponent("absent.store"),
      realmURL: directory.appendingPathComponent("absent.realm")
    )

    XCTAssertFalse(userDefaults.bool(forKey: SampleData.seededFlagKey))
  }
}
