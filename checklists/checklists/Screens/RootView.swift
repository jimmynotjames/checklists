//
//  RootView.swift
//  checklists
//

import SwiftData
import SwiftUI

/// The app's main scene once startup has succeeded: the checklists list inside a
/// `NavigationStack`, with the main menu layered above it and the router's sheets presented over
/// it.
struct RootView: View {
  @Environment(Router.self) private var router
  @Environment(\.modelContext) private var context
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Read back so the main menu can become a side panel on a wide window.
  @State private var rootWidth: CGFloat = 0

  /// How long the main menu takes to slide in or out.
  static let menuAnimationSeconds: TimeInterval = 0.2

  /// The main menu's width once it stops covering the whole window.
  static let menuPanelWidth: CGFloat = 360

  /// Whether the main menu is a side panel over a dimmed list rather than full-screen: only when
  /// the list beside it keeps at least the panel's own width.
  static func menuIsSidePanel(in width: CGFloat) -> Bool {
    width >= menuPanelWidth * 2
  }

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
      if router.isMainMenuVisible, Self.menuIsSidePanel(in: rootWidth) {
        // Decorative: VoiceOver is held in the panel by its modal trait, and closes it with the
        // panel's own button or the escape gesture.
        Color.black.opacity(0.3)
          .ignoresSafeArea()
          .onTapGesture { router.isMainMenuVisible = false }
          .accessibilityHidden(true)
          .zIndex(1)
          .transition(.opacity)
      }
      if router.isMainMenuVisible {
        MainMenuView()
          .frame(maxWidth: Self.menuIsSidePanel(in: rootWidth) ? Self.menuPanelWidth : .infinity)
          .frame(maxWidth: .infinity, alignment: .leading)
          .zIndex(2)
          // Reduce Motion suppresses simulated spatial movement, not animation itself: the
          // panel cross-fades in place instead of sliding from the leading edge.
          .transition(reduceMotion ? .opacity : .move(edge: .leading))
      }
    }
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rootWidth = $0 }
    .animation(.easeInOut(duration: Self.menuAnimationSeconds), value: router.isMainMenuVisible)
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
        case let .transferCheckedItems(sourceID, mode):
          if let source = context.checklist(id: sourceID) {
            CopyCheckedItemsView(source: source, mode: mode)
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
      // The sheet's own toast layer; see `ToastPresenterModifier`.
      .toastOverlay()
    }
  }

  /// A route can stop resolving between being appended and being rendered (e.g. the record was
  /// deleted on another device). Render nothing and quietly pop rather than crashing. Quietly, unlike
  /// the open screen catching the same deletion first, which says why (`Toast.checklistDeletedElsewhere`).
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
