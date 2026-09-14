//
//  AppStartupCoordinator.swift
//  checklists
//

import Foundation
import SwiftData

/**
 Everything that has to happen between the process starting and the first screen being able to
 show data: open the store, copy anything left in the old Realm store, seed a brand-new install.

 Kept out of the app and scene delegates so the whole sequence is one testable unit, and so its
 failure has somewhere to go other than a crash.

 Safe to run more than once — that is what the failure screen's Retry does.
 */
@MainActor
final class AppStartupCoordinator {
  enum Outcome {
    case ready(container: ModelContainer, backing: ContainerBacking)
    case failed(ContainerCreationFailure)
  }

  typealias MakeContainer = @MainActor () throws -> (container: ModelContainer, backing: ContainerBacking)

  private let makeContainer: MakeContainer
  private let analytics: any AnalyticsClient

  init(
    makeContainer: @escaping MakeContainer = LaunchModeContainerFactory.make,
    analytics: any AnalyticsClient = AppAnalytics.shared
  ) {
    self.makeContainer = makeContainer
    self.analytics = analytics
  }

  /// Whether this launch has to copy data out of the old Realm store.
  ///
  /// Read *before* startup runs, so the caller can put the migration screen up first. Only ever
  /// true on the single launch that follows an upgrade from a Realm build.
  static var willImportLegacyData: Bool {
    !LaunchModeContainerFactory.isRunningTests && LegacyRealmImporter.isNeeded()
  }

  func run() -> Outcome {
    do {
      let (container, backing) = try makeContainer()

      // Automated tests get a disposable in-memory store that is already seeded; importing the
      // simulator's leftover Realm file into it would be both wrong and slow.
      if !LaunchModeContainerFactory.isRunningTests {
        try LegacyRealmImporter.importIfNeeded(into: container.mainContext)
        try SampleData.insertFirstTimeLaunchDataIfNeeded(into: container.mainContext)
        // Deliberately not `try`: duplicate untouched samples are cosmetic, and failing to tidy
        // them is no reason to show the failure screen instead of the user's checklists.
        // `saveChanges` has already logged anything that went wrong.
        try? SampleData.dedupeChecklists(in: container.mainContext)
      }

      PersistenceController.install(
        PersistenceController(modelContainer: container, containerBacking: backing)
      )
      AppLog.bootstrap.info("bootstrap.ready: backing=\(String(describing: backing), privacy: .public)")
      return .ready(container: container, backing: backing)
    } catch {
      // Covers three different problems on purpose — the store would not open, the Realm copy did
      // not complete, the fixture would not save — because the user-facing answer to all three is
      // the same: do not continue into a screen that would look like their data is gone. Nothing
      // has been deleted in any of these cases; the Realm file is still on disk.
      let failure = ContainerCreationFailure(underlying: error)
      AppLog.bootstrap.error("bootstrap.failed: \(failure.diagnosticDescription, privacy: .public)")
      analytics.track(
        AnalyticsEvent.startupFailed,
        properties: [
          AnalyticsProperty.errorDomain: failure.errorDomain,
          AnalyticsProperty.errorCode: failure.errorCode,
        ]
      )
      return .failed(failure)
    }
  }
}
