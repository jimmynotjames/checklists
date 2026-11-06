//
//  ChecklistBar.swift
//  checklists
//

import Observation
import SwiftUI

/// The checklist screen's navigation bar as state: what `ChecklistViewController` decides and
/// `ChecklistScreen`'s toolbar draws. The controller is the only writer; the toolbar reads it and
/// sends taps back through `perform`.
@MainActor
@Observable
final class ChecklistBar {
  enum Mode {
    case idle
    /// A field on the screen is being typed into.
    case typing
    case reordering
  }

  /// A button in the bar. `primary` is Reset on an existing checklist and the create sheet's Done.
  enum Item: Hashable {
    case more
    case primary
    case editingDone
    case reorderDone
  }

  /// Everything a bar button or a ⋯ menu entry can ask the controller to do.
  enum Action {
    case primary
    case editingDone
    case reorderDone
    case reorderItems
    case duplicate
    case copyCheckedItems
    case moveCheckedItems
    case exportPDF
    case deleteCheckedItems
    case deleteChecklist
  }

  /// A request to move VoiceOver to a bar item. `generation` makes a repeat of the same item a
  /// change the toolbar can observe.
  struct FocusRequest: Equatable {
    let item: Item
    let generation: Int
  }

  private(set) var mode: Mode = .idle
  /// The create sheet's bar, with Done and Discard, rather than an existing checklist's.
  var isNewChecklist = false
  /// The checklist's name once it has scrolled under the bar; `nil` while the name is on screen.
  private(set) var title: String?
  private(set) var focusRequest: FocusRequest?

  /// Set by the controller. A no-op until then, so a toolbar drawn early does nothing.
  @ObservationIgnored var perform: (Action) -> Void = { _ in }
  /// ⌘N, which has no bar button. Set by the controller, like `perform`.
  @ObservationIgnored var addItem: () -> Void = {}

  /// The item pinned at the outer edge: at the top of iPhone Duo's vertical bar, under Back, and
  /// never in the overflow. Always the screen's Done of the moment.
  var pinnedItem: Item? {
    switch mode {
    case .reordering: .reorderDone
    case .typing: .editingDone
    case .idle: isNewChecklist ? .primary : nil
    }
  }

  /// The unpinned trailing items, outer edge first. Reorder Items mode clears the bar down to its
  /// Done, as ChecklistsView's Edit mode does. The create sheet's Done is pinned instead, as a
  /// sheet's confirming action sits; an existing checklist keeps Reset on the title side of ⋯.
  var trailingItems: [Item] {
    switch mode {
    case .reordering: []
    case .idle, .typing: isNewChecklist ? [.more] : [.more, .primary]
    }
  }

  /// The ⋯ menu's inline sections, top first. Gaps keep a thumb reaching for Move off the Deletes,
  /// and Export, which sends something out of the app, apart from the moves inside it. Nothing on
  /// the create sheet's checklist has been kept yet, so copying, moving, exporting or pruning it
  /// means nothing there; reordering does, right after typing a batch of items.
  var menuSections: [[Action]] {
    if isNewChecklist {
      return [[.reorderItems], [.deleteChecklist]]
    }
    return [
      [.reorderItems],
      [.duplicate, .copyCheckedItems, .moveCheckedItems],
      [.exportPDF],
      [.deleteCheckedItems, .deleteChecklist],
    ]
  }

  func setMode(_ newMode: Mode, animated: Bool) {
    guard newMode != mode else { return }
    if animated {
      withAnimation { mode = newMode }
    } else {
      mode = newMode
    }
  }

  func setTitle(_ newTitle: String?) {
    guard newTitle != title else { return }
    withAnimation(.easeInOut(duration: 0.4)) { title = newTitle }
  }

  func requestFocus(on item: Item) {
    focusRequest = FocusRequest(item: item, generation: (focusRequest?.generation ?? 0) + 1)
  }
}
