//
//  ChecklistViewController+Strings.swift
//  checklists
//

import Foundation

/// The detail screen's localized copy, kept beside the controller rather than in it so the
/// controller stays about behavior.
extension ChecklistViewController {
  /// Persisted as the checklist's name, so it stays in whatever language the device had when saved.
  static let defaultChecklistName = String(
    localized: "checklist.defaultName",
    defaultValue: "untitled checklist",
    comment: "Name stored for a checklist saved with an empty name field. Lowercase in English; it is data once saved."
  )

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

  static let deleteConfirmationMessage = String(
    localized: "checklists.confirm.irreversible",
    defaultValue: "Are you sure? This cannot be undone.",
    comment: "Alert message under both the delete-checklist and the reset-all confirmations."
  )

  static let deleteActionTitle = String(
    localized: "common.action.delete",
    defaultValue: "Delete",
    comment: "Destructive action: removes a checklist. Swipe action and confirmation button."
  )

  static let cancelActionTitle = String(
    localized: "common.action.cancel",
    defaultValue: "Cancel",
    comment: "Dismisses a confirmation alert without doing anything."
  )
}
