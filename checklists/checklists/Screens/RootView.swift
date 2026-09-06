//
//  RootView.swift
//  checklists
//

import SwiftData
import SwiftUI

/// The app's main scene once startup has succeeded: the checklists list inside a
/// `NavigationStack`, with the slide-in main menu layered above it and sheets for
/// Settings and the new-checklist flow. Modeled on budgets1's `RootView`.
struct RootView: View {
  @Environment(Router.self) private var router
  @Environment(\.modelContext) private var context

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
                // The view controller does its own keyboard avoidance via contentInset (the reason
                // it ditched UITableViewController); opt out of SwiftUI's so they don't stack.
                .ignoresSafeArea(.keyboard)
              } else {
                unresolvedPushDestination
              }
            }
          }
      }
      if router.isMainMenuVisible {
        MainMenuView()
          .zIndex(1)
          .transition(.move(edge: .leading))
      }
    }
    // Matches the old MainMenuTransitionAnimator's 0.2s horizontal slide.
    .animation(.easeInOut(duration: 0.2), value: router.isMainMenuVisible)
    .tint(Colors.tealColor)
    .sheet(item: $router.sheet) { route in
      Group {
        switch route {
        case .settings:
          SettingsView()
        case let .newChecklist(id):
          if let checklist = context.checklist(id: id) {
            ChecklistScreen(checklist: checklist, isNewChecklist: true) {
              router.sheet = nil
            }
            .ignoresSafeArea(.keyboard)
          } else {
            unresolvedSheetDestination
          }
        }
      }
      // Sheets don't inherit the navigation stack's tint; re-apply it (budgets1 pattern).
      .tint(Colors.tealColor)
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
