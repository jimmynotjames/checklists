//
//  PreviewSupport.swift
//  checklists
//

#if DEBUG
  import SwiftData
  import SwiftUI

  /// Shared fixtures for the `#Preview` blocks at the bottom of each view file.
  ///
  /// `@MainActor` because `context` reaches a container's main context.
  @MainActor
  enum PreviewSupport {
    /// In-memory, CloudKit-free container holding the `SampleData` fixture — the same three
    /// checklists first launch seeds, so a preview shows what a real install shows.
    static let container: ModelContainer = make(InMemoryModelContainer.makeSeeded)

    /// For the empty-list state, which the seeded container cannot show.
    static let emptyContainer: ModelContainer = make(InMemoryModelContainer.makeEmpty)

    static let router = Router()

    /// Never `UserDefaults.standard`: a preview toggling analytics consent must not leave a
    /// decision behind on the simulator.
    static let analyticsSettings = AnalyticsSettings(store: InMemoryKeyValueStore())

    static var context: ModelContext {
      container.mainContext
    }

    static func checklist(id: String = SampleData.morningRoutineId) -> Checklist {
      guard let checklist = context.checklist(id: id) else {
        fatalError("PreviewSupport fixture is missing checklist \(id).")
      }
      return checklist
    }

    static func syncStatus(
      containerBacking: ContainerBacking = .cloudKit,
      accountStatus: SyncStatus.AccountStatus = .available,
      syncActivity: [SyncOperation: SyncOperationState] = [:]
    ) -> SyncStatus {
      let status = SyncStatus(containerBacking: containerBacking, accountStatus: accountStatus)
      status.syncActivity = syncActivity
      return status
    }

    static func analyticsSettings(optedIn: Bool) -> AnalyticsSettings {
      let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
      settings.analyticsOptIn = optedIn
      return settings
    }

    private static func make(_ build: @MainActor () throws -> ModelContainer) -> ModelContainer {
      do {
        return try build()
      } catch {
        fatalError("PreviewSupport could not build an in-memory container: \(error)")
      }
    }
  }

  extension View {
    /// Everything the SwiftUI shell injects at launch, so a previewed screen finds the same
    /// environment it finds in the app. `\.analytics` is deliberately absent — it already
    /// defaults to `ConsoleAnalyticsClient`.
    ///
    /// `toasts` is a fresh instance per call rather than a `PreviewSupport` fixture, deliberately
    /// unlike `router` above: default-argument expressions are evaluated per call, and a shared
    /// presenter would leave one preview's toast showing in its neighbours — the leak `RootView`'s
    /// "Main menu open" preview already works around for `Router`.
    func previewEnvironment(
      container: ModelContainer = PreviewSupport.container,
      router: Router = PreviewSupport.router,
      syncStatus: SyncStatus = PreviewSupport.syncStatus(),
      analyticsSettings: AnalyticsSettings = PreviewSupport.analyticsSettings,
      toasts: ToastPresenter = ToastPresenter()
    ) -> some View {
      modelContainer(container)
        .environment(router)
        .environment(syncStatus)
        .environment(analyticsSettings)
        .environment(toasts)
    }
  }
#endif
