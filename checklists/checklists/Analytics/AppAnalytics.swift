//
//  AppAnalytics.swift
//  checklists
//

/**
 Process-wide analytics handle, for the three call sites that run before any SwiftUI environment
 exists.

 Deliberately narrow. `ProductionContainerFactory.make()` runs inside `AppStartupCoordinator.run()`
 inside `AppStartupModel.init()` — there is no view, no environment, and no `self` to thread a
 client through. Every screen uses `@Environment(\.analytics)` instead, and the UIKit checklist
 screen has one injected by its SwiftUI host.

 Its three consumers take the client as a defaulted parameter rather than reading this directly,
 so all three stay testable:

   - `ProductionContainerFactory.make(cloud:local:analytics:)`
   - `AppStartupCoordinator.init(makeContainer:analytics:)`
   - `ModelContext.saveChanges(operation:analytics:)`

 Do not add a fourth caller without changing this comment.

 > **Install it before startup runs.** `ChecklistsApp` must call `install(_:)` before constructing
 > `AppStartupModel`, which means the model cannot use an inline property initializer: stored
 > properties are initialized before the body of `init()`. Get that order wrong and these three
 > events go to the console client in every build, silently. See analytics-spec.md §7.3.
 */
@MainActor
enum AppAnalytics {
  private(set) static var shared: any AnalyticsClient = ConsoleAnalyticsClient()

  static func install(_ client: any AnalyticsClient) {
    shared = client
  }
}
