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

 Safe to run more than once, which is what the failure screen's "Start over fresh" relies on.
 */
@MainActor
final class AppStartupCoordinator {
  enum Outcome {
    case ready(container: ModelContainer, backing: ContainerBacking)
    case failed(ContainerCreationFailure)
  }

  typealias MakeContainer = @MainActor () throws -> (container: ModelContainer, backing: ContainerBacking)
  typealias StageWork = @MainActor (ModelContext) throws -> Void

  private let makeContainer: MakeContainer
  private let importLegacyData: StageWork
  private let seedFirstLaunchData: StageWork
  private let runsPostOpenStages: Bool
  private let analytics: any AnalyticsClient

  /// The two stage closures and `runsPostOpenStages` exist so a test can reach the stages after the
  /// store opens. In an automated run they are skipped entirely, so without a seam the only
  /// reachable stage is the first one and nothing proves the other two are tagged as themselves.
  init(
    makeContainer: @escaping MakeContainer = LaunchModeContainerFactory.make,
    importLegacyData: @escaping StageWork = { try LegacyRealmImporter.importIfNeeded(into: $0) },
    seedFirstLaunchData: @escaping StageWork = { try SampleData.insertFirstTimeLaunchDataIfNeeded(into: $0) },
    runsPostOpenStages: Bool = !LaunchModeContainerFactory.isRunningTests,
    analytics: any AnalyticsClient = AppAnalytics.shared
  ) {
    self.makeContainer = makeContainer
    self.importLegacyData = importLegacyData
    self.seedFirstLaunchData = seedFirstLaunchData
    self.runsPostOpenStages = runsPostOpenStages
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
      let (container, backing) = try tagging(.storeOpen) { try makeContainer() }

      // Automated tests get a disposable in-memory store that is already seeded; importing the
      // simulator's leftover Realm file into it would be both wrong and slow.
      if runsPostOpenStages {
        try tagging(.legacyImport) { try importLegacyData(container.mainContext) }
        try tagging(.firstLaunchSeed) { try seedFirstLaunchData(container.mainContext) }
        // Swallowed rather than propagated: duplicate untouched samples are cosmetic, and failing
        // to tidy them is no reason to show the failure screen instead of the user's checklists.
        // `saveChanges` has already logged anything that went wrong.
        try? SampleData.dedupeChecklists(in: container.mainContext)
      }

      PersistenceController.install(
        PersistenceController(modelContainer: container, containerBacking: backing)
      )
      AppLog.bootstrap.info("bootstrap.ready: backing=\(String(describing: backing), privacy: .public)")
      return .ready(container: container, backing: backing)
    } catch let failure {
      // All three stages land here on purpose: the user-facing answer to all three starts the same,
      // which is to not continue into a screen that would look like their data is gone. What
      // differs is the recovery, which `failure.stage` decides.
      AppLog.bootstrap.error("bootstrap.failed: \(failure.diagnosticDescription, privacy: .public)")
      analytics.track(
        AnalyticsEvent.startupFailed,
        properties: [
          AnalyticsProperty.errorDomain: failure.errorDomain,
          AnalyticsProperty.errorCode: failure.errorCode,
          AnalyticsProperty.startupStage: failure.stage.rawValue,
        ]
      )
      return .failed(failure)
    }
  }

  /// Tags whatever `work` throws with the stage it threw in, so the catch above can tell "the store
  /// would not open" from "the store opened and a later stage failed".
  ///
  /// The typed `throws(ContainerCreationFailure)` is what makes the caller's single `catch`
  /// exhaustive: adding a `try` that bypasses this helper becomes a compile error rather than an
  /// untagged failure reaching a screen whose whole purpose is that startup never crashes.
  private func tagging<T>(
    _ stage: ContainerCreationFailure.Stage,
    _ work: () throws -> T
  ) throws(ContainerCreationFailure) -> T {
    do {
      return try work()
    } catch {
      throw ContainerCreationFailure(underlying: error, stage: stage)
    }
  }
}
