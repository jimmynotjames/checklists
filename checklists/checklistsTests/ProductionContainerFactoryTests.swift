//
//  ProductionContainerFactoryTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import XCTest

/// Covers `ProductionContainerFactory`'s branch selection and the store-URL invariant it depends
/// on, using injected `MakeContainer` closures rather than the real on-disk store.
///
/// See the doc comment on `DataModelTests` for why this class is `nonisolated` at the type level
/// with individual `@MainActor` test methods.
nonisolated final class ProductionContainerFactoryTests: XCTestCase {
  /// CloudKit is the preferred store, so it must be attempted before the local fallback is even
  /// considered.
  ///
  /// (This replaces the tripwire that asserted the opposite while CloudKit was switched off. It was
  /// written to fail deliberately on the day the flag flipped, and it did.)
  @MainActor func testCloudKitPathIsTriedFirst() throws {
    XCTAssertTrue(ProductionContainerFactory.cloudKitEnabled)

    let stubContainer = try TestModelContainer.make()
    var configurationOfferedToCloud: ModelConfiguration?
    var localAttempted = false

    let result = try ProductionContainerFactory.make(
      cloud: { configuration in
        configurationOfferedToCloud = configuration
        return stubContainer
      },
      local: { _ in
        localAttempted = true
        return stubContainer
      }
    )

    XCTAssertEqual(result.backing, .cloudKit)
    XCTAssertFalse(localAttempted, "The local fallback must not run when CloudKit succeeds.")
    XCTAssertEqual(configurationOfferedToCloud?.url, ProductionContainerFactory.storeURL())
  }

  /// iCloud being unavailable is an ordinary state — no account, no network on a first launch, a
  /// simulator that has never signed in — and must degrade to the local store rather than failing.
  @MainActor func testFallsBackToLocalWhenCloudKitIsUnavailable() throws {
    let stubContainer = try TestModelContainer.make()
    var configurationOfferedToLocal: ModelConfiguration?

    let result = try ProductionContainerFactory.make(
      cloud: { _ in throw NSError(domain: "CKErrorDomain", code: 9) },
      local: { configuration in
        configurationOfferedToLocal = configuration
        return stubContainer
      }
    )

    XCTAssertEqual(result.backing, .localFallback)
    XCTAssertEqual(
      configurationOfferedToLocal?.url,
      ProductionContainerFactory.storeURL(),
      "The fallback must open the same file, so a local-only session is promoted in place once iCloud returns."
    )
  }

  /// This is the invariant that prevents an offline first launch from forking into a second,
  /// never-synced store: both configurations, and the shared `storeURL()` they are pinned to, must
  /// resolve to the exact same file.
  @MainActor func testCloudAndLocalConfigurationsShareStoreURL() {
    let storeURL = ProductionContainerFactory.storeURL()
    XCTAssertEqual(ProductionContainerFactory.cloudConfiguration().url, storeURL)
    XCTAssertEqual(ProductionContainerFactory.localConfiguration().url, storeURL)
  }

  @MainActor func testContainerCreationFailurePropagates() throws {
    let failingError = NSError(domain: "TestDomain", code: 42)

    XCTAssertThrowsError(
      try ProductionContainerFactory.make(
        cloud: { _ in throw failingError },
        local: { _ in throw failingError }
      )
    ) { error in
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, "TestDomain")
      XCTAssertEqual(nsError.code, 42)
    }
  }
}
