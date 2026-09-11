//
//  ChecklistsApp.swift
//  checklists
//

import SwiftUI
import UIKit

@main
struct ChecklistsApp: App {
  /// **Deliberately not an inline initializer.** Stored properties are initialized before the
  /// body of `init()` runs, and `AppStartupModel.init()` synchronously runs the whole startup
  /// sequence — including the three analytics call sites in the persistence layer. Initializing
  /// it here would mean those events fire before `AppAnalytics.install(_:)` and go to the console
  /// client in every build, with no error. See core-docs/analytics-spec.md §7.3.
  @State private var startup: AppStartupModel
  @State private var router = Router()
  @State private var appOpenTracker = AppOpenTracker()
  @State private var analyticsSettings = AnalyticsSettings()

  @Environment(\.scenePhase) private var scenePhase

  private let analytics: any AnalyticsClient

  init() {
    let client = Self.makeAnalyticsClient()
    // Install first: the startup sequence below emits analytics.
    AppAnalytics.install(client)
    analytics = client
    _startup = State(initialValue: AppStartupModel())

    // From the Apple docs, I'm slightly worried about power usage by turning this on, but can find nothing online saying this is a power hog.
    // TODO-DEFERRED: Nevertheless, once we collect stats on landscape/portrait, maybe remove this?
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
  }

  var body: some Scene {
    WindowGroup {
      Group {
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
              guard let value = orientationAnalyticsValue(UIDevice.current.orientation) else { return }
              analytics.track(AnalyticsEvent.orientationChanged, properties: [AnalyticsProperty.orientation: value])
            }
        case let .failed(failure):
          // Deliberately gets none of the *data* environment: the store may be unsafe, and this
          // screen only reports the failure and offers the fresh-start reset. It does get the
          // analytics client (injected below, for every phase) — that is a plain object built in
          // `init()` with no dependence on the wedged store, and `startup_store_reset` paired with
          // `startup_failed` is the most useful ratio in this app's catalog.
          ContainerFailureView(failure: failure) {
            startup.rerunAfterStoreReset()
          }
        }
      }
      // On the Group rather than any one branch: the loading screen is up for at least 1.5s on a
      // legacy-import launch, and the failure branch never becomes `.ready` at all. Attaching this
      // to `.ready` would delay `app_opened` on migration launches and drop it entirely for anyone
      // stuck on the failure screen — the population most worth counting. Keeping the modifiers
      // outside the switch also stops them remounting when the phase changes, which would reset
      // the tracker and let a duplicate open through.
      .environment(\.analytics, analytics)
      .environment(analyticsSettings)
      .task {
        // The scene's real phase, not a hardcoded `.active`: the app declares the
        // remote-notification background mode, so it can be launched into the background, and
        // asserting `.active` there would both invent an open and suppress the person's real one.
        // The tracker dedupes this against the `.onChange` below, so a launch never fires twice.
        fireAppOpenedIfNeeded(for: scenePhase)
      }
      .onChange(of: scenePhase) { _, newPhase in
        fireAppOpenedIfNeeded(for: newPhase)
      }
    }
  }

  private func fireAppOpenedIfNeeded(for phase: ScenePhase) {
    guard appOpenTracker.shouldFire(for: phase) else { return }
    analytics.track(AnalyticsEvent.appOpened)
  }

  /// Which client this build talks to.
  ///
  /// TODO-DEFERRED: returns the console client unconditionally until the Mixpanel SDK lands, at
  /// which point this becomes the selection described in analytics-spec.md §7.1 — Mixpanel when
  /// the token is configured and we are not running tests, console otherwise.
  private static func makeAnalyticsClient() -> any AnalyticsClient {
    ConsoleAnalyticsClient()
  }
}
