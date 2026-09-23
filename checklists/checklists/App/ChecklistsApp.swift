//
//  ChecklistsApp.swift
//  checklists
//

import SwiftUI
import UIKit

@main
struct ChecklistsApp: App {
  /// **Deliberately not an inline initializer.** Stored properties are initialized before the
  /// body of `init()` runs, and `AppStartupModel.init()` can run the whole startup sequence
  /// synchronously, analytics included. Inline, those events would fire before
  /// `AppAnalytics.install(_:)` and go to the console client in every build, with no error. See
  /// analytics-spec.md §Non-SwiftUI callers.
  @State private var startup: AppStartupModel
  @State private var router = Router()
  @State private var appOpenTracker = AppOpenTracker()
  /// Inline is safe here, unlike the two below: it takes no dependencies and emits nothing.
  @State private var toasts = ToastPresenter()
  /// Not inline: `init()` needs this exact instance to build the consent gate's `isOptedIn`
  /// closure before injecting it into the environment below.
  @State private var analyticsSettings: AnalyticsSettings
  /// Built in `init()` because it takes the gated client: its events go through the consent gate,
  /// while its eligibility counters (`RatingPromptState`) are deliberately not gated.
  @State private var ratingPrompt: RatingPromptCoordinator

  @Environment(\.scenePhase) private var scenePhase

  private let analytics: any AnalyticsClient

  init() {
    let settings = AnalyticsSettings()
    let base = Self.makeAnalyticsClient(settings: settings)
    // Every call site reaches the base client through this gate, so an opted-out install never
    // touches it — see `ConsentGatedAnalyticsClient` and analytics-spec.md §Launch and consent
    // ordering.
    let client = ConsentGatedAnalyticsClient(wrapping: base, isOptedIn: { [settings] in settings.analyticsOptIn })
    // Install first: the startup sequence below emits analytics.
    AppAnalytics.install(client)
    analytics = client
    _analyticsSettings = State(initialValue: settings)
    _ratingPrompt = State(initialValue: RatingPromptCoordinator(state: RatingPromptState(), analytics: client))
    _startup = State(initialValue: AppStartupModel())

    // TODO: revisit once rotation stats land.
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
            // Innermost on purpose: a modifier reads the environment of its *ancestors*, and every
            // `.environment(...)` below is applied outside these two, so this is the only position
            // from which either presenter can see `Router`, the coordinator and the toast
            // presenter. Put them after those and the app traps at launch on the missing
            // observable. Only the ready branch has the rating prompt: it is fed by check-offs,
            // which only happen here.
            .ratingPromptPresenter()
            .toastPresenter()
            .modelContainer(container)
            .environment(router)
            // Reuse the instance PersistenceController installed at startup rather than building
            // one here: `SyncStatus` is derived from which store that run actually opened, which
            // only the coordinator knows.
            .environment(PersistenceController.shared.syncStatus)
            .environment(ratingPrompt)
            .environment(toasts)
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
              guard let value = orientationAnalyticsValue(UIDevice.current.orientation) else { return }
              analytics.track(AnalyticsEvent.orientationChanged, properties: [AnalyticsProperty.orientation: value])
            }
        case let .failed(failure):
          // Deliberately gets none of the *data* environment: the store may be unsafe. It does get
          // the analytics client (injected below, for every phase) — a plain object built in
          // `init()` with no dependence on the wedged store — so `startup_store_reset` can be
          // read against `startup_failed`.
          ContainerFailureView(failure: failure) {
            startup.rerunAfterStoreReset()
          }
        }
      }
      #if DEBUG
        // On the Group so the loading and failure screens scale too; see `TestDynamicTypeOverride`.
      .modifier(TestDynamicTypeOverride())
      #endif
      .environment(\.analytics, analytics)
      .environment(analyticsSettings)
      // On the Group, not one switch branch: attaching to `.ready` would drop `app_opened` entirely
      // for anyone stuck on the failure screen. Keeping modifiers outside the switch also stops them
      // remounting on phase changes, which would reset the tracker and let a duplicate open through.
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

  /// Which client this build talks to — analytics-spec.md §Client selection.
  ///
  /// The consent gate wraps whatever this returns (see `init()` above), so this makes no opt-in
  /// check of its own: a test run or an unconfigured token falls back to the console client,
  /// otherwise every call reaches a real `MixpanelAnalyticsClient`, gated one layer up.
  ///
  /// Test detection is `LaunchModeContainerFactory.isRunningTests`, which documents the signals
  /// it accepts; a UI test sets only one of them, so a narrower check could let it reach real
  /// Mixpanel.
  private static func makeAnalyticsClient(settings: AnalyticsSettings) -> any AnalyticsClient {
    guard
      !shouldUseConsoleClient(
        isRunningTests: LaunchModeContainerFactory.isRunningTests,
        isTokenConfigured: MixpanelTokenSource.isConfigured
      )
    else {
      return ConsoleAnalyticsClient()
    }
    return MixpanelAnalyticsClient(
      token: MixpanelTokenSource.activeToken,
      // Captured strongly on purpose: this is the only path by which the persisted `distinct_id`
      // reaches Mixpanel, and `settings` lives for the app's lifetime anyway.
      distinctIdProvider: { settings.analyticsDistinctId }
    )
  }

  /// The truth table behind `makeAnalyticsClient()`, pulled out so it is testable without
  /// touching `LaunchModeContainerFactory` or `MixpanelTokenSource` directly. Pinned by
  /// `AnalyticsClientSelectionTests`. `true` means "use `ConsoleAnalyticsClient`" — a test run, or a build with no configured
  /// token, both fall back rather than reach real Mixpanel.
  static func shouldUseConsoleClient(isRunningTests: Bool, isTokenConfigured: Bool) -> Bool {
    isRunningTests || !isTokenConfigured
  }
}
