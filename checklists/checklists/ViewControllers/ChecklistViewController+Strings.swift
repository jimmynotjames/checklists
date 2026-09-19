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
    Overflow-menu entry on the new-checklist sheet that throws the unsaved checklist away. \
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
}
