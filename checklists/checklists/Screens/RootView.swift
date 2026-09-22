//
//  RootView.swift
//  checklists
//

import SwiftData
import SwiftUI

/// The app's main scene once startup has succeeded: the checklists list inside a
/// `NavigationStack`, with the main menu layered above it and sheets for
/// Settings and the new-checklist flow. Modeled on `simple-recurring-budgets`'s `RootView`.
struct RootView: View {
  @Environment(Router.self) private var router
  @Environment(\.modelContext) private var context
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    @Bindable var router = router
    ZStack {
      NavigationStack(path: $router.path) {
        ChecklistsView()
          .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case let .checklist(id):
              if let checklist = context.checklist(id: id) {
                ChecklistScreen(checklist: checklist) {
                  guard !router.path.isEmpty else { return }
                  router.path.removeLast()
                }
                // Only the embedded UIKit bar should show for this destination; see ChecklistScreen.
                .toolbar(.hidden, for: .navigationBar)
              } else {
                unresolvedPushDestination
              }
            }
          }
      }
      if router.isMainMenuVisible {
        MainMenuView()
          .zIndex(1)
          // Reduce Motion suppresses simulated spatial movement, not animation itself: the
          // panel cross-fades in place instead of sliding from the leading edge.
          .transition(reduceMotion ? .opacity : .move(edge: .leading))
      }
    }
    .animation(.easeInOut(duration: 0.2), value: router.isMainMenuVisible)
    .sheet(item: $router.sheet) { route in
      Group {
        switch route {
        case .settings:
          SettingsView()
        case .analyticsConsent:
          AnalyticsConsentSheet()
        case let .newChecklist(id):
          if let checklist = context.checklist(id: id) {
            ChecklistScreen(checklist: checklist, isNewChecklist: true) {
              router.sheet = nil
            }
          } else {
            unresolvedSheetDestination
          }
        }
      }
      #if DEBUG
        // Sheets present in their own environment and do not inherit the root's
        // dynamicTypeSize, so the override has to be reapplied here or the
        // large-type check would silently photograph settings at the default size.
      .modifier(TestDynamicTypeOverride())
      #endif
      // A sheet is presented outside the root overlay's hierarchy, so a toast raised while one
      // is up can only be drawn from in here. The root layer stands down for the duration, so
      // only one of the two ever draws.
      .toastOverlay()
    }
  }

  /// A route can stop resolving between being appended and being rendered (e.g. the record was
  /// deleted on another device). Render nothing and quietly pop rather than crashing.
  private var unresolvedPushDestination: some View {
    Color.clear.onAppear {
      guard !router.path.isEmpty else { return }
      router.path.removeLast()
    }
  }

  private var unresolvedSheetDestination: some View {
    Color.clear.onAppear {
      router.sheet = nil
    }
  }
}

#if DEBUG
  #Preview("Root") {
    RootView()
      .previewEnvironment()
  }

  #Preview("Main menu open") {
    // A fresh `Router`, not `PreviewSupport.router`: that instance is shared by every other
    // preview in this process, and mutating `isMainMenuVisible` on it would leak into them.
    RootView()
      .previewEnvironment(router: {
        let router = Router()
        router.isMainMenuVisible = true
        return router
      }())
  }
#endif
