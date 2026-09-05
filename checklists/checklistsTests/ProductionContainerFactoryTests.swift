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
  /// With CloudKit off for this release, `make` must not attempt the CloudKit path at all, and must
  /// report the store it actually opened.
  ///
  /// **This test is expected to need updating when CloudKit is switched on** — deliberately, so
  /// that flipping `cloudKitEnabled` cannot pass unnoticed. At that point it should assert the
  /// opposite: that `cloud` is tried first, and that a throwing `cloud` closure falls back to
  /// `local` and reports `.localFallback`. That fallback cannot be exercised while the flag is off,
  /// because the cloud closure is never reached.
  ///
  /// `ModelConfiguration.CloudKitDatabase` is not `Equatable`, so the configuration's setting cannot
  /// be asserted directly. Asserting on the branch taken is the better test anyway: it pins
  /// behaviour rather than a field, and it does so through injected closures, so no container is
  /// ever built at the real `storeURL()`.
  @MainActor func testCloudKitDisabledSkipsTheCloudPathEntirely() throws {
    XCTAssertFalse(
      ProductionContainerFactory.cloudKitEnabled,
      "CloudKit is expected to be off in this release; see this test's doc comment."
    )

    let stubContainer = try TestModelContainer.make()
    var cloudAttempted = false
    var configurationOfferedToLocal: ModelConfiguration?

    let result = try ProductionContainerFactory.make(
      cloud: { _ in
        cloudAttempted = true
        return stubContainer
      },
      local: { configuration in
        configurationOfferedToLocal = configuration
        return stubContainer
      }
    )

    XCTAssertFalse(cloudAttempted, "The CloudKit path must not be attempted while it is disabled.")
    XCTAssertEqual(result.backing, .localFallback)
    XCTAssertEqual(
      configurationOfferedToLocal?.url,
      ProductionContainerFactory.storeURL(),
      "The local store must be opened at the shared, pinned URL."
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
