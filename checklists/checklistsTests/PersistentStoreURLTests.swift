//
//  PersistentStoreURLTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import XCTest

/// Guards the single-store invariant behind `ProductionContainerFactory`: a `ModelConfiguration`'s
/// on-disk `url` is independent of its `cloudKitDatabase` setting, which is what lets an
/// offline-first store be promoted to CloudKit-backed in place rather than forking into a second,
/// empty file. Ported from `budgets1`'s `PersistentStoreURLTests`
/// (`simple-recurring-budgetsTests/App/PersistentStoreURLTests.swift`), converted from Swift
/// Testing's `#expect` to `XCTAssertEqual`.
///
/// These pin SwiftData's own behavior directly, independent of `ProductionContainerFactoryTests`,
/// so a regression in the framework itself surfaces here rather than only downstream.
///
/// See the doc comment on `DataModelTests` for why this class is `nonisolated` at the type level
/// with individual `@MainActor` test methods.
nonisolated final class PersistentStoreURLTests: XCTestCase {
  /// The default (implicit-URL) configuration exposes a concrete on-disk URL both real
  /// configurations can be anchored to.
  @MainActor func testDefaultConfigurationExposesStableURL() {
    let schema = SchemaV1.swiftDataSchema
    let first = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    let second = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    XCTAssertEqual(first.url, second.url)
  }

  /// Pinning the same explicit `url` yields the same store file regardless of whether CloudKit
  /// mirroring is enabled.
  @MainActor func testCloudAndLocalConfigsShareStoreURLWhenPinned() {
    let schema = SchemaV1.swiftDataSchema
    let storeURL = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false).url

    let cloud = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .automatic)
    let local = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)

    XCTAssertEqual(cloud.url, storeURL)
    XCTAssertEqual(local.url, storeURL)
    XCTAssertEqual(cloud.url, local.url)
  }
}
