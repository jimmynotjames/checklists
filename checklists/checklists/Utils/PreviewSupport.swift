//
//  PreviewSupport.swift
//  checklists
//

#if DEBUG
  import SwiftData
  import SwiftUI

  /// Shared fixtures for the `#Preview` blocks at the bottom of each view file.
  ///
  /// `@MainActor` because building the container also installs a `PersistenceController`, which
  /// is main-actor-isolated.
  @MainActor
  enum PreviewSupport {
    /// In-memory, CloudKit-free container holding the `SampleData` fixture — the same three
    /// checklists first launch seeds, so a preview shows what a real install shows.
    ///
    /// Installing `PersistenceController` as a side effect of the first access is deliberate:
    /// `ChecklistViewController` reaches for `PersistenceController.shared` in `viewDidLoad`, so
    /// without it `ChecklistScreen`'s preview hits `preconditionFailure`. Each preview runs in
    /// its own process, so this writes to nothing the app or the tests can see.
    static let container: ModelContainer = makeInstalledContainer()

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
      accountStatus: SyncStatus.AccountStatus = .available
    ) -> SyncStatus {
      SyncStatus(containerBacking: containerBacking, accountStatus: accountStatus)
    }

    static func analyticsSettings(optedIn: Bool) -> AnalyticsSettings {
      let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
      settings.analyticsOptIn = optedIn
      return settings
    }

    private static func makeInstalledContainer() -> ModelContainer {
      let container = make(InMemoryModelContainer.makeSeeded)
      PersistenceController.install(
        PersistenceController(modelContainer: container, containerBacking: .cloudKit)
      )
      return container
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
    func previewEnvironment(
      container: ModelContainer = PreviewSupport.container,
      router: Router = PreviewSupport.router,
      syncStatus: SyncStatus = PreviewSupport.syncStatus(),
      analyticsSettings: AnalyticsSettings = PreviewSupport.analyticsSettings
    ) -> some View {
      modelContainer(container)
        .environment(router)
        .environment(syncStatus)
        .environment(analyticsSettings)
    }
  }
#endif
