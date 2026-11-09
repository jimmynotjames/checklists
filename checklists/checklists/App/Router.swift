//
//  Router.swift
//  checklists
//

import SwiftUI

/// Centralised navigation state for the SwiftUI shell, owned by the app's root view as `@State`
/// and injected into the environment so any descendant screen can open a checklist or present a
/// sheet without a direct reference to the host.
///
/// At most one checklist is open at a time, so the state is a selection rather than a path: the
/// detail column of `RootView`'s split view on a wide window, a push over ChecklistsView on a
/// narrow one. Screens ask the questions below instead of reading the selection and sheet
/// themselves.
@Observable
@MainActor
final class Router {
  /// The open checklist's `Checklist.id`; `nil` while no checklist is open.
  ///
  /// The stable `id`, never a live model reference: the destination resolves it when it is shown,
  /// via `ModelContext.checklist(id:)`, and quietly closes when the record no longer exists (e.g.
  /// deleted on another device).
  var selectedChecklistID: String?
  var sheet: SheetRoute?

  /// No checklist open and no sheet up. On a wide window ChecklistsView is on screen beside the
  /// open checklist too, but the open checklist still counts as frontmost.
  var isChecklistsViewFrontmost: Bool {
    selectedChecklistID == nil && sheet == nil
  }

  func isFrontmost(checklistID: String) -> Bool {
    sheet == nil && selectedChecklistID == checklistID
  }

  func open(checklistID: String) {
    selectedChecklistID = checklistID
  }

  /// Closes the checklist only if it is still the open one: a screen leaving late, after another
  /// checklist has replaced it, must not close its successor.
  func closeChecklist(id: String) {
    guard selectedChecklistID == id else { return }
    selectedChecklistID = nil
  }

  /// The selection as `NavigationSplitView`'s preferred compact column. On a narrow window an open
  /// checklist shows as the detail column pushed over ChecklistsView, and the back button or swipe
  /// writes `.sidebar`, which closes it. The split view never writes `.detail` on its own; opening
  /// goes through `open(checklistID:)`.
  var compactColumn: NavigationSplitViewColumn {
    get { selectedChecklistID == nil ? .sidebar : .detail }
    set {
      if newValue == .sidebar {
        selectedChecklistID = nil
      }
    }
  }
}
