//
//  SceneDelegate.swift
//  checklists
//
//  Created by Jimmy Ho on 8/30/26.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  /// How long the migration screen stays up once it has been shown.
  ///
  /// The copy itself takes a small fraction of this for any realistic amount of data. Without a
  /// floor the screen would flash by unread, which is worse than a brief wait: this is the one
  /// moment to explain why the launch is different and that iCloud sync is now in play.
  private static let minimumMigrationScreenDuration: Duration = .seconds(1.5)

  func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    self.window = window

    if AppStartupCoordinator.willImportLegacyData {
      window.rootViewController = LoadingViewController()
      window.makeKeyAndVisible()
      Task { @MainActor [weak self] in
        await self?.runStartupBehindLoadingScreen(in: window)
      }
    } else {
      // The overwhelmingly common path: no migration, so nothing to wait for and no reason to show
      // an intermediate screen. Identical to how the app has always launched.
      install(AppStartupCoordinator().run(), in: window)
      window.makeKeyAndVisible()
    }
  }

  @MainActor
  private func runStartupBehindLoadingScreen(in window: UIWindow) async {
    let minimumDisplay = Task {
      try? await Task.sleep(for: Self.minimumMigrationScreenDuration)
    }
    // Give the loading screen a turn of the run loop to actually render: the work below is
    // synchronous (SwiftData's main context and Realm both require the main thread) and would
    // otherwise block before the first frame.
    await Task.yield()

    let outcome = AppStartupCoordinator().run()

    if case let .ready(_, backing) = outcome,
       let loadingViewController = window.rootViewController as? LoadingViewController {
      loadingViewController.showsCloudSyncNote = (backing == .cloudKit)
    }

    await minimumDisplay.value
    install(outcome, in: window)
  }

  @MainActor
  private func install(_ outcome: AppStartupCoordinator.Outcome, in window: UIWindow) {
    switch outcome {
    case .ready:
      window.rootViewController = UINavigationController(rootViewController: ChecklistsViewController(style: .plain))
    case let .failed(failure):
      let failureViewController = ContainerFailureViewController(failure: failure)
      failureViewController.delegate = self
      window.rootViewController = failureViewController
    }
  }
}

extension SceneDelegate: ContainerFailureViewControllerDelegate {
  func containerFailureViewControllerDidResetStore(_: ContainerFailureViewController) {
    guard let window else { assertionFailure(); return }
    // The stores are already gone, so this run starts from nothing: a fresh container, no import,
    // and first-launch seeding. If it fails again — a full disk, say — the same screen returns,
    // which is the honest outcome.
    install(AppStartupCoordinator().run(), in: window)
  }
}
