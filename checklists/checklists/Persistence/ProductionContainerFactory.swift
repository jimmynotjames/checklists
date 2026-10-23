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

  /// Whether to attempt a CloudKit-backed store. Capability and container setup:
  /// persistence-design.md §CloudKit ops record.
  ///
  /// The local-only fallback is selected by *any* throw from the CloudKit-configured
  /// `ModelContainer` initializer, not by an iCloud account check: a schema that violates a
  /// CloudKit constraint, a migration failure and a corrupt store all land there, and `make(...)`
  /// keeps the error's domain and code (`fallbackError`) rather than discarding which it was.
  /// `.automatic` is expected (not verified) to initialize with nobody signed in, so read the local
  /// path as "the CloudKit store would not open", not "the user is signed out".
  static let cloudKitEnabled = true

  /// The one on-disk location both configurations use: the default configuration's own `url`, so
  /// both land on the file an existing install already has. If the two resolved independently, a
  /// launch without iCloud would write one file and a later launch with it would open a different,
  /// empty one. Sharing the URL promotes the local store to a synced store in place.
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
  /// the default is the process-wide handle. See analytics-spec.md §Non-SwiftUI callers.
  static func make(
    cloud: MakeContainer = realContainer,
    local: MakeContainer = realContainer,
    analytics: any AnalyticsClient = AppAnalytics.shared,
  ) throws -> ContainerLaunchResult {
    var fallbackError: SyncErrorCode?

    if cloudKitEnabled {
      do {
        let container = try cloud(cloudConfiguration())
        AppLog.cloudKit.info("cloudkit.container.backed")
        return ContainerLaunchResult(container: container, backing: .cloudKit, fallbackError: nil)
      } catch let error as NSError {
        // Not treated as an error: the local store is a working app, just an unsynced one.
        AppLog.cloudKit.notice(
          "cloudkit.container.localFallback: \(error.domain, privacy: .public) \(error.code, privacy: .public)",
        )
        // A sibling call, not derived from the OSLog line above: analytics-spec.md §OSLog boundary.
        analytics.track(
          AnalyticsEvent.cloudkitContainerFellBack,
          properties: [
            AnalyticsProperty.errorDomain: error.domain,
            AnalyticsProperty.errorCode: error.code,
          ],
        )
        fallbackError = SyncErrorCode(domain: error.domain, code: error.code)
      }
    }

    do {
      let container = try local(localConfiguration())
      return ContainerLaunchResult(container: container, backing: .localFallback, fallbackError: fallbackError)
    } catch let error as NSError {
      AppLog.cloudKit.error(
        "cloudkit.container.failed: \(error.domain, privacy: .public) \(error.code, privacy: .public) \(error.localizedDescription, privacy: .public)",
      )
      analytics.track(
        AnalyticsEvent.persistenceFatalError,
        properties: [
          AnalyticsProperty.errorDomain: error.domain,
          AnalyticsProperty.errorCode: error.code,
        ],
      )
      throw error
    }
  }

  /// The real initializer both closures default to.
  static func realContainer(for configuration: ModelConfiguration) throws -> ModelContainer {
    try ModelContainer(
      for: SchemaV1.swiftDataSchema,
      migrationPlan: ChecklistsMigrationPlan.self,
      configurations: configuration,
    )
  }
}
