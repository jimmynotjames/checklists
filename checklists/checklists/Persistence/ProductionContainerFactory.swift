//
//  ProductionContainerFactory.swift
//  checklists
//

import Foundation
import SwiftData

/**
 Builds the app's real on-disk persistence stack.

 The container-creation closures are injectable because the real `ModelContainer` initializers
 cannot be made to fail on demand, and the branch selection here — which store the app ends up
 running on — is the part worth testing.
 */
enum ProductionContainerFactory {
  typealias MakeContainer = @MainActor (ModelConfiguration) throws -> ModelContainer

  /// Whether to attempt a CloudKit-backed store.
  ///
  /// On: the iCloud capability, the `iCloud.com.jimmyho.checklists` container and the
  /// remote-notification background mode are all in place. The local-only path below is still the
  /// fallback, not dead code — but note what actually selects it: *any* throw from the
  /// CloudKit-configured `ModelContainer` initializer, not an iCloud account check. A schema that
  /// violates a CloudKit constraint, a migration failure and a corrupt store all land there too,
  /// and `try?` discards which it was. A missing account is not expected to be among them:
  /// `.automatic` should initialize with nobody signed in and simply not sync. Nothing here
  /// verifies that, so treat the local path as "the CloudKit store would not open", not as
  /// "the user is signed out".
  static let cloudKitEnabled = true

  /// The one on-disk location both configurations use.
  ///
  /// Asking SwiftData for the default configuration's own `url` — rather than hardcoding a path —
  /// pins both the CloudKit-backed and local-only configurations to the exact file an existing
  /// install already has. If the two were
  /// ever allowed to resolve independently, a launch with iCloud unavailable would write to one
  /// file and a later launch with iCloud available would open a different, empty one, and the
  /// user's first session would appear to vanish. Sharing the URL means the local store is
  /// promoted to a synced store in place.
  static func storeURL() -> URL {
    ModelConfiguration(schema: SchemaV1.swiftDataSchema, isStoredInMemoryOnly: false).url
  }

  static func cloudConfiguration() -> ModelConfiguration {
    ModelConfiguration(schema: SchemaV1.swiftDataSchema, url: storeURL(), cloudKitDatabase: .automatic)
  }

  static func localConfiguration() -> ModelConfiguration {
    ModelConfiguration(schema: SchemaV1.swiftDataSchema, url: storeURL(), cloudKitDatabase: .none)
  }

  /// CloudKit-backed if possible, otherwise local-only. Throws only when both paths fail.
  /// `analytics` is a parameter rather than a direct `AppAnalytics.shared` read so the failure
  /// branch below is testable; it runs long before any SwiftUI environment exists, which is why
  /// the default is the process-wide handle. See analytics-spec.md §7.3.
  static func make(
    cloud: MakeContainer = realContainer,
    local: MakeContainer = realContainer,
    analytics: any AnalyticsClient = AppAnalytics.shared
  ) throws -> (container: ModelContainer, backing: ContainerBacking) {
    if cloudKitEnabled {
      if let container = try? cloud(cloudConfiguration()) {
        AppLog.cloudKit.info("cloudkit.container.backed")
        return (container, .cloudKit)
      }
      // Not treated as an error: the local store is a working app, just an unsynced one.
      AppLog.cloudKit.notice("cloudkit.container.localFallback")
    }

    do {
      let container = try local(localConfiguration())
      return (container, .localFallback)
    } catch let error as NSError {
      AppLog.cloudKit.error(
        "cloudkit.container.failed: \(error.domain, privacy: .public) \(error.code, privacy: .public) \(error.localizedDescription, privacy: .public)"
      )
      analytics.track(
        AnalyticsEvent.persistenceFatalError,
        properties: [
          AnalyticsProperty.errorDomain: error.domain,
          AnalyticsProperty.errorCode: error.code,
        ]
      )
      throw error
    }
  }

  /// The real initializer both closures default to.
  static func realContainer(for configuration: ModelConfiguration) throws -> ModelContainer {
    try ModelContainer(
      for: SchemaV1.swiftDataSchema,
      migrationPlan: ChecklistsMigrationPlan.self,
      configurations: configuration
    )
  }
}
