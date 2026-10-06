//
//  ChecklistViewController+Strings.swift
//  checklists
//

import Foundation

/// The detail screen's localized copy, kept beside the controller rather than in it so the
/// controller stays about behavior.
extension ChecklistViewController {
  static let resetButtonTitle = String(
    localized: "checklist.action.reset",
    defaultValue: "Reset",
    comment: "Navigation bar button on the checklist detail screen that unchecks every item so the list can be run again."
  )

  // MARK: Overflow menu

  static let reorderItemsMenuTitle = String(
    localized: "checklist.menu.reorderItems",
    defaultValue: "Reorder Items",
    comment: """
    First overflow-menu entry on a checklist's screen, both for a saved checklist and while \
    creating one. Shows drag handles for putting this checklist's items in a new order; a Done \
    button leaves. It does not edit the items' text and does not sort them, so avoid a verb that \
    could read as sorting.
    """
  )

  static let moreMenuAccessibilityLabel = String(
    localized: "checklist.menu.more.accessibilityLabel",
    defaultValue: "More",
    comment: "VoiceOver label for the ellipsis button in the checklist detail screen's navigation bar that opens the overflow menu."
  )

  static let duplicateChecklistMenuTitle = String(
    localized: "checklist.menu.duplicateChecklist",
    defaultValue: "Duplicate Checklist",
    comment: """
    Overflow-menu entry on an existing checklist's detail screen that makes a copy of it. \
    Not destructive and not confirmed: it opens the copy straight away. It sits above the \
    Delete Checklist entry, so the two must not read alike.
    """
  )

  static let copyCheckedItemsMenuTitle = String(
    localized: "checklist.menu.copyCheckedItems",
    defaultValue: "Copy Checked Items to…",
    comment: """
    Overflow-menu entry on an existing checklist's detail screen. Copies the items the person has \
    ticked into another checklist, picked on the sheet that opens next. Keep the trailing \
    ellipsis — it is what promises that sheet. It sits directly under the Duplicate Checklist \
    entry and must not read alike: that one copies the whole list, this one copies a selection \
    into a different list.
    """
  )

  static let noItemsCheckedNotice = String(
    localized: "checklist.menu.copyCheckedItems.noCheckedItems",
    defaultValue: "No checked items.",
    comment: """
    Appears inside the overflow menu, directly under the Copy Checked Items to… entry, when that \
    entry is tapped with nothing ticked, and fades again after a moment. Not a button — it says \
    why nothing happened. Echo the wording of checklist.menu.copyCheckedItems: it should read as \
    "there are none of the thing that entry copies", so reuse that key's word for checked items \
    rather than picking a synonym. Keep it to a few words.
    """
  )

  static let deleteChecklistMenuTitle = String(
    localized: "checklist.menu.deleteChecklist",
    defaultValue: "Delete Checklist",
    comment: "Overflow-menu entry on an existing checklist's detail screen. Destructive; a confirmation follows."
  )

  /// "Discard", not "Delete": nothing about the create sheet's checklist has been kept yet.
  static let discardChecklistMenuTitle = String(
    localized: "checklist.menu.discardChecklist",
    defaultValue: "Discard Checklist",
    comment: """
    Overflow-menu entry on the new-checklist sheet that throws the new checklist away. \
    Destructive; a confirmation follows. It must read differently from the Delete Checklist \
    entry, which removes a kept list: this one abandons something never kept.
    """
  )

  static let discardConfirmationMessage = String(
    localized: "checklist.confirm.discard.message",
    defaultValue: "Discard this checklist? This cannot be undone.",
    comment: "Alert message before discarding a brand-new checklist from its create sheet."
  )

  static let discardActionTitle = String(
    localized: "checklist.action.discard",
    defaultValue: "Discard",
    comment: """
    Confirmation button that throws away a brand-new checklist. It sits beside Cancel on the \
    same alert, so it must not be the word your language uses for Cancel, and it is not Delete \
    either: this checklist was never kept. Prefer the sense of abandon or throw away. Keep it short.
    """
  )

  // MARK: VoiceOver moves

  static func moveActionTitle(for action: ChecklistMoveAction) -> String {
    switch action {
    case .up:
      String(
        localized: "item.accessibilityAction.moveUp",
        defaultValue: "Move Up",
        comment: "VoiceOver action on an item row inside a checklist: moves the item one place up."
      )
    case .down:
      String(
        localized: "item.accessibilityAction.moveDown",
        defaultValue: "Move Down",
        comment: "VoiceOver action on an item row inside a checklist: moves the item one place down."
      )
    case .top:
      String(
        localized: "item.accessibilityAction.moveToTop",
        defaultValue: "Move to Top",
        comment: "VoiceOver action on an item row inside a checklist: moves the item to the start of the checklist."
      )
    case .bottom:
      String(
        localized: "item.accessibilityAction.moveToBottom",
        defaultValue: "Move to Bottom",
        comment: "VoiceOver action on an item row inside a checklist: moves the item to the end of the checklist."
      )
    }
  }

  static func movedToPositionAnnouncement(position: Int, count: Int) -> String {
    String(
      localized: "item.accessibility.movedToPosition",
      defaultValue: "Moved to position \(position) of \(count)",
      comment: """
      VoiceOver announcement after an item inside a checklist is moved with a Move Up/Down/to \
      Top/to Bottom action. First placeholder is its new position counting from 1, second the \
      number of items in the checklist.
      """
    )
  }
}
