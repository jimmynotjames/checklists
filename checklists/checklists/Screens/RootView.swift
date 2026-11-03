//
//  RootView.swift
//  checklists
//

import SwiftData
import SwiftUI

/// The app's main scene once startup has succeeded: the checklists list inside a
/// `NavigationStack`, with the router's sheets presented over it.
struct RootView: View {
  @Environment(Router.self) private var router
  @Environment(\.modelContext) private var context

  var body: some View {
    @Bindable var router = router
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
              // The screen lends its UIKit bar items to this bar; see
              // ChecklistViewController+BarHost. Visible explicitly: holding no SwiftUI items of its
              // own, the bar is otherwise hidden as empty while the screen appears, lent items and
              // all.
              .toolbarVisibility(.visible, for: .navigationBar)
            } else {
              unresolvedPushDestination
            }
          }
        }
    }
    .sheet(item: $router.sheet) { route in
      Group {
        switch route {
        case .settings:
          SettingsView()
        case .analyticsConsent:
          AnalyticsConsentSheet()
        case let .newChecklist(id):
          if let checklist = context.checklist(id: id) {
            // A stack of its own only for the bar it brings, which the screen lends its items to.
            NavigationStack {
              ChecklistScreen(checklist: checklist, isNewChecklist: true) {
                router.sheet = nil
              }
              .toolbarVisibility(.visible, for: .navigationBar)
              // Inline, as the embedded bar always was: the scroll handler puts the name in the
              // title, which a large-title bar would grow a row for.
              .navigationBarTitleDisplayMode(.inline)
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
#endif
