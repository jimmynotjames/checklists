//
//  ProductionContainerFactoryTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing

/// Covers `ProductionContainerFactory`'s branch selection and the store-URL invariant it depends
/// on, using injected `MakeContainer` closures rather than the real on-disk store.
@Suite("ProductionContainerFactory branch selection")
struct ProductionContainerFactoryTests {
  /// CloudKit is the preferred store, so it must be attempted before the local fallback is even
  /// considered.
  @Test("CloudKit is tried before the local fallback")
  func cloudKitPathIsTriedFirst() throws {
    #expect(ProductionContainerFactory.cloudKitEnabled)

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
      },
    )

    #expect(result.backing == .cloudKit)
    #expect(!localAttempted, "The local fallback must not run when CloudKit succeeds.")
    #expect(configurationOfferedToCloud?.url == ProductionContainerFactory.storeURL())
  }

  /// A CloudKit-backed container that will not initialize must degrade to the local store rather
  /// than failing the launch: an unsynced app is a working app.
  @Test("an unavailable CloudKit falls back to the local store")
  func fallsBackToLocalWhenCloudKitIsUnavailable() throws {
    let stubContainer = try TestModelContainer.make()
    var configurationOfferedToLocal: ModelConfiguration?

    let result = try ProductionContainerFactory.make(
      cloud: { _ in throw NSError(domain: "CKErrorDomain", code: 9) },
      local: { configuration in
        configurationOfferedToLocal = configuration
        return stubContainer
      },
    )

    #expect(result.backing == .localFallback)
    #expect(
      configurationOfferedToLocal?.url == ProductionContainerFactory.storeURL(),
      "The fallback must open the same file, so a local-only session is promoted in place once iCloud returns.",
    )
  }

  /// This is the invariant that prevents an offline first launch from forking into a second,
  /// never-synced store: both configurations, and the shared `storeURL()` they are pinned to, must
  /// resolve to the exact same file.
  @Test("the cloud and local configurations share the same store URL")
  func cloudAndLocalConfigurationsShareStoreURL() {
    let storeURL = ProductionContainerFactory.storeURL()
    #expect(ProductionContainerFactory.cloudConfiguration().url == storeURL)
    #expect(ProductionContainerFactory.localConfiguration().url == storeURL)
  }

  @Test("a container-creation failure from both branches propagates")
  func containerCreationFailurePropagates() throws {
    let failingError = NSError(domain: "TestDomain", code: 42)

    let error = #expect(throws: (any Error).self) {
      try ProductionContainerFactory.make(
        cloud: { _ in throw failingError },
        local: { _ in throw failingError },
      )
    }
    let nsError = error as NSError?
    #expect(nsError?.domain == "TestDomain")
    #expect(nsError?.code == 42)
  }
}
