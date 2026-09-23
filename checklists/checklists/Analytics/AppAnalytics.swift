//
//  AppAnalytics.swift
//  checklists
//

/**
 Process-wide analytics handle, for the persistence call sites that run before any SwiftUI
 environment exists.

 Deliberately narrow. `ProductionContainerFactory.make()` runs inside `AppStartupCoordinator.run()`
 inside `AppStartupModel.init()` — there is no view, no environment, and no `self` to thread a
 client through. Every screen uses `@Environment(\.analytics)` instead, and the UIKit checklist
 screen has one injected by its SwiftUI host.

 Consumers take the client as a defaulted parameter rather than reading this directly, so they
 stay testable. **Install before startup runs**, or their events silently go to the console client
 — core-docs/analytics-spec.md §Non-SwiftUI callers.
 */
@MainActor
enum AppAnalytics {
  private(set) static var shared: any AnalyticsClient = ConsoleAnalyticsClient()

  static func install(_ client: any AnalyticsClient) {
    shared = client
  }
}
