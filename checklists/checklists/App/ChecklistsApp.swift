//
//  ChecklistsApp.swift
//  checklists
//

import SwiftUI
import UIKit

@main
struct ChecklistsApp: App {
  @State private var startup = AppStartupModel()
  @State private var router = Router()

  init() {
    AnalyticsManager.appLaunched()

    // From the Apple docs, I'm slightly worried about power usage by turning this on, but can find nothing online saying this is a power hog.
    // TODO-DEFERRED: Nevertheless, once we collect stats on landscape/portrait, maybe remove this?
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
  }

  var body: some Scene {
    WindowGroup {
      switch startup.phase {
      case let .loading(showsCloudSyncNote):
        LoadingView(showsCloudSyncNote: showsCloudSyncNote)
      case let .ready(container, _):
        RootView()
          .modelContainer(container)
          .environment(router)
          // Reuse the instance PersistenceController installed at startup — the failure-retry path
          // patches it in place, so creating a second SyncStatus would split the source of truth.
          .environment(PersistenceController.shared.syncStatus)
          .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            AnalyticsManager.logDeviceOrientationChange()
          }
      case let .failed(failure):
        // Deliberately gets none of the app environment: the store may be unsafe, and this screen
        // only reports the failure and offers the fresh-start reset.
        ContainerFailureView(failure: failure) {
          startup.rerunAfterStoreReset()
        }
      }
    }
  }
}
