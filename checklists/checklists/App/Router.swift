//
//  Router.swift
//  checklists
//

import Foundation

/// Centralised navigation state for the SwiftUI shell, owned by the app's root view as `@State`
/// and injected into the environment so any descendant screen can open a checklist or present a
/// sheet without a direct reference to the host.
///
/// At most one checklist is open at a time, so the state is a selection rather than a path. Screens
/// ask the questions below instead of reading the selection and sheet themselves.
@Observable
@MainActor
final class Router {
  /// The open checklist's `Checklist.id`; `nil` while ChecklistsView is all there is.
  var selectedChecklistID: String?
  var sheet: SheetRoute?

  /// Whether ChecklistsView is the screen in front: no checklist open over it and no sheet.
  var isChecklistsViewFrontmost: Bool {
    selectedChecklistID == nil && sheet == nil
  }

  /// Whether the checklist with this id is open and nothing is presented over it.
  func isFrontmost(checklistID: String) -> Bool {
    sheet == nil && selectedChecklistID == checklistID
  }

  func open(checklistID: String) {
    selectedChecklistID = checklistID
  }

  func closeChecklist() {
    selectedChecklistID = nil
  }

  /// The selection as a `NavigationStack` path: empty, or the one open checklist.
  var stackPath: [AppRoute] {
    get { selectedChecklistID.map { [.checklist(id: $0)] } ?? [] }
    set {
      selectedChecklistID = newValue.last.map { route in
        switch route {
        case let .checklist(id): id
        }
      }
    }
  }
}
