//
//  RootView.swift
//  checklists
//

import SwiftData
import SwiftUI

/// The app's main scene once startup has succeeded: ChecklistsView and the open checklist in a
/// `NavigationSplitView`, with the router's sheets presented over it.
///
/// One container for every width. On a wide window (regular width: iPhone Duo unfolded, a large
/// iPhone in landscape, a wide iPad or Mac window) the two sit side by side; on a narrow one the
/// split view collapses to a stack and the open checklist is pushed over ChecklistsView. Folding or
/// unfolding collapses and expands the same views, so the open checklist, its scroll position and
/// an edit in progress survive it.
struct RootView: View {
  @Environment(Router.self) private var router
  @Environment(\.modelContext) private var context
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    @Bindable var router = router
    // Both columns always: there is no sidebar button, so nothing hides ChecklistsView on a wide
    // window. A collapsed split view ignores this and follows `compactColumn`.
    NavigationSplitView(columnVisibility: .constant(.all), preferredCompactColumn: $router.compactColumn) {
      ChecklistsView()
        .toastOverlay(.list)
        .toolbar(removing: .sidebarToggle)
        // A sidebar's bottom bar is hidden by default beside a detail column, and it holds Add.
        .toolbarVisibility(.visible, for: .bottomBar)
        // Read here, not in the column: a split view's columns are compact themselves.
        .environment(\.isChecklistBesideList, horizontalSizeClass == .regular)
    } detail: {
      detail
    }
    .navigationSplitViewStyle(.balanced)
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

  @ViewBuilder private var detail: some View {
    if let id = router.selectedChecklistID {
      if let checklist = context.checklist(id: id) {
        ChecklistScreen(checklist: checklist) {
          router.closeChecklist(id: id)
        }
        .toastOverlay(.checklist(id: id))
        // A new screen for each checklist: the controller takes its checklist once, when it is
        // made, so without this, opening another checklist beside the list would keep the old one.
        .id(id)
      } else {
        unresolvedDetail(id: id)
      }
    } else {
      NoChecklistSelectedView()
    }
  }

  /// A checklist can stop resolving between being opened and being rendered (e.g. the record was
  /// deleted on another device). Render nothing and quietly close it rather than crashing. Quietly,
  /// unlike the open screen catching the same deletion first, which says why
  /// (`Toast.checklistDeletedElsewhere`).
  private func unresolvedDetail(id: String) -> some View {
    Color.clear.onAppear {
      router.closeChecklist(id: id)
    }
  }

  private var unresolvedSheetDestination: some View {
    Color.clear.onAppear {
      router.sheet = nil
    }
  }
}

extension EnvironmentValues {
  /// Whether ChecklistsView sits beside the open checklist, as `RootView`'s split view does on a
  /// wide window, rather than under it. Only then does the open checklist's row show as selected.
  @Entry var isChecklistBesideList = false
}

/// The detail column on a wide window while no checklist is open.
private struct NoChecklistSelectedView: View {
  var body: some View {
    Text(Self.title)
      .font(.title3)
      .foregroundStyle(Colors.inactiveTextColor)
      .multilineTextAlignment(.center)
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .appBackground()
  }

  private static let title = String(
    localized: "checklists.noneSelected",
    defaultValue: "No Checklist Selected",
    comment: "Shown beside the list of checklists on a wide screen (an unfolded iPhone Duo, a large iPhone in landscape) while no checklist is open.",
  )
}

#if DEBUG
  #Preview("Root") {
    RootView()
      .previewEnvironment()
  }

  // Wide enough for both columns, as on iPhone Duo's inner display.
  #Preview("Root, wide", traits: .fixedLayout(width: 1000, height: 800)) {
    RootView()
      .previewEnvironment()
      .environment(\.horizontalSizeClass, .regular)
  }
#endif
