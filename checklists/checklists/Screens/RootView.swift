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
    NavigationStack(path: $router.stackPath) {
      ChecklistsView()
        .toastOverlay(.list)
        .navigationDestination(for: AppRoute.self) { route in
          switch route {
          case let .checklist(id):
            if let checklist = context.checklist(id: id) {
              ChecklistScreen(checklist: checklist) {
                router.closeChecklist()
              }
              .toastOverlay(.checklist(id: id))
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
            // A stack of its own, for the screen's toolbar.
            NavigationStack {
              ChecklistScreen(checklist: checklist, isNewChecklist: true) {
                router.sheet = nil
              }
              .toastOverlay(.sheet)
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
    }
  }

  /// A route can stop resolving between being appended and being rendered (e.g. the record was
  /// deleted on another device). Render nothing and quietly pop rather than crashing. Quietly, unlike
  /// the open screen catching the same deletion first, which says why (`Toast.checklistDeletedElsewhere`).
  private var unresolvedPushDestination: some View {
    Color.clear.onAppear {
      router.closeChecklist()
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
