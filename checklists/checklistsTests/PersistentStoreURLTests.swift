//
//  PersistentStoreURLTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing

/// Guards the single-store invariant behind `ProductionContainerFactory`: a `ModelConfiguration`'s
/// on-disk `url` is independent of its `cloudKitDatabase` setting, which is what lets an
/// offline-first store be promoted to CloudKit-backed in place rather than forking into a second,
/// empty file. Ported from `budgets1`'s suite of the same name
/// (`simple-recurring-budgetsTests/App/PersistentStoreURLTests.swift`).
///
/// These pin SwiftData's own behavior directly, independent of `ProductionContainerFactoryTests`,
/// so a regression in the framework itself surfaces here rather than only downstream.
@Suite("Persistent store URL invariants")
struct PersistentStoreURLTests {
  /// The default (implicit-URL) configuration exposes a concrete on-disk URL both real
  /// configurations can be anchored to.
  @Test("the default configuration exposes a stable URL")
  func defaultConfigurationExposesStableURL() {
    let schema = SchemaV1.swiftDataSchema
    let first = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    let second = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    #expect(first.url == second.url)
  }

  /// Pinning the same explicit `url` yields the same store file regardless of whether CloudKit
  /// mirroring is enabled.
  @Test("cloud and local configs share a store URL when pinned to the same one")
  func cloudAndLocalConfigsShareStoreURLWhenPinned() {
    let schema = SchemaV1.swiftDataSchema
    let storeURL = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false).url

    let cloud = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .automatic)
    let local = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)

    #expect(cloud.url == storeURL)
    #expect(local.url == storeURL)
    #expect(cloud.url == local.url)
  }
}
