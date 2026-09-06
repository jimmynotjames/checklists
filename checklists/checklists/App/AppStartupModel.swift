//
//  AppStartupModel.swift
//  checklists
//

import Foundation
import SwiftData

/**
 The startup sequence, as a phase the SwiftUI app body can switch on.

 This is the SwiftUI replacement for `SceneDelegate`'s window-swapping: instead of installing a
 different root view controller at each step, the same root view renders whichever `Phase` this
 model is currently in. The branching, the ordering, and the timing are ported from
 `SceneDelegate` unchanged — see the comments on each step, which explain *why* the sequence is
 shaped this way.

 `AppStartupCoordinator` still owns the actual work. This type owns only when it runs and what
 the screen shows while it does.
 */
@Observable
@MainActor
final class AppStartupModel {
  enum Phase {
    /// The one-time Realm copy is running. `showsCloudSyncNote` is false until the store's
    /// backing is known, then flipped mid-flight once it turns out to be CloudKit.
    case loading(showsCloudSyncNote: Bool)
    case ready(container: ModelContainer, backing: ContainerBacking)
    case failed(ContainerCreationFailure)
  }

  /// How long the migration screen stays up once it has been shown.
  ///
  /// The copy itself takes a small fraction of this for any realistic amount of data. Without a
  /// floor the screen would flash by unread, which is worse than a brief wait: this is the one
  /// moment to explain why the launch is different and that iCloud sync is now in play.
  private static let minimumMigrationScreenDuration: Duration = .seconds(1.5)

  private(set) var phase: Phase

  init() {
    if AppStartupCoordinator.willImportLegacyData {
      phase = .loading(showsCloudSyncNote: false)
      Task { [weak self] in
        await self?.runStartupBehindLoadingScreen()
      }
    } else {
      // The overwhelmingly common path: no migration, so nothing to wait for and no reason to show
      // an intermediate screen. Identical to how the app has always launched.
      phase = Self.phase(for: AppStartupCoordinator().run())
    }
  }

  /// Re-runs startup after the failure screen's "Start over fresh" has deleted every local store.
  ///
  /// The stores are already gone, so this run starts from nothing: a fresh container, no import,
  /// and first-launch seeding. If it fails again — a full disk, say — the same screen returns,
  /// which is the honest outcome.
  func rerunAfterStoreReset() {
    phase = Self.phase(for: AppStartupCoordinator().run())
  }

  private func runStartupBehindLoadingScreen() async {
    let minimumDisplay = Task {
      try? await Task.sleep(for: Self.minimumMigrationScreenDuration)
    }
    // Give the loading screen a turn of the run loop to actually render: the work below is
    // synchronous (SwiftData's main context and Realm both require the main thread) and would
    // otherwise block before the first frame.
    await Task.yield()

    let outcome = AppStartupCoordinator().run()

    if case let .ready(_, backing) = outcome, case .loading = phase {
      phase = .loading(showsCloudSyncNote: backing == .cloudKit)
    }

    await minimumDisplay.value
    phase = Self.phase(for: outcome)
  }

  private static func phase(for outcome: AppStartupCoordinator.Outcome) -> Phase {
    switch outcome {
    case let .ready(container, backing):
      .ready(container: container, backing: backing)
    case let .failed(failure):
      .failed(failure)
    }
  }
}
