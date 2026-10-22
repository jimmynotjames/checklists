//
//  ChecklistsView+Strings.swift
//  checklists
//

import Foundation

/// What the list of checklists says to VoiceOver — its name, and what changed after a delete, a
/// duplicate or a reset — and what its confirmation alerts ask.
extension ChecklistsView {
  static let screenTitle = String(
    localized: "checklists.title",
    defaultValue: "Checklists",
    comment: """
    Name of the app's main screen, the list of all checklists. Not drawn on screen: VoiceOver reads \
    it as the screen's title. A plural noun, not a verb.
    """
  )

  static let deletedAnnouncement = String(
    localized: "checklists.accessibility.deleted",
    defaultValue: "Checklist deleted",
    comment: """
    VoiceOver announcement after a checklist is deleted from the list of checklists. VoiceOver then \
    moves to a neighbouring checklist, or to the Add button when none are left. Keep it short.
    """
  )

  static let duplicatedAnnouncement = String(
    localized: "checklists.accessibility.duplicated",
    defaultValue: "Checklist duplicated",
    comment: """
    VoiceOver announcement after a checklist is duplicated with its swipe action. The copy appears \
    directly below the original. Keep it short.
    """
  )

  static let allResetAnnouncement = String(
    localized: "checklists.accessibility.allReset",
    defaultValue: "All checklists reset",
    comment: """
    VoiceOver announcement after Reset All unchecks every item in every checklist. "Reset" matches \
    the Reset All button; nothing is deleted. Keep it short.
    """
  )

  static func bulkAnnouncement(for action: ChecklistsBulkAction, count: Int) -> String {
    switch action {
    case .delete:
      String(
        localized: "checklists.accessibility.bulkDeleted",
        defaultValue: "\(count) checklists deleted",
        comment: """
        VoiceOver announcement after Edit mode's Delete removes the selected checklists. The \
        placeholder is how many were deleted. Keep it short.
        """
      )
    case .duplicate:
      String(
        localized: "checklists.accessibility.bulkDuplicated",
        defaultValue: "\(count) checklists duplicated",
        comment: """
        VoiceOver announcement after Edit mode's Duplicate copies the selected checklists. The \
        placeholder is how many were copied. Keep it short.
        """
      )
    case .reset:
      String(
        localized: "checklists.accessibility.bulkReset",
        defaultValue: "\(count) checklists reset",
        comment: """
        VoiceOver announcement after Edit mode's Reset unchecks every item in the selected \
        checklists. "Reset" matches the button; nothing is deleted. The placeholder is how many \
        checklists were reset. Keep it short.
        """
      )
    }
  }
}

// MARK: - Confirmation alerts

/// Each alert's title asks the question, naming what it acts on; the message under it says it can't
/// be undone.
extension ChecklistsView {
  /// A blank name reads as the name an unnamed checklist carries everywhere else.
  static func deleteConfirmationTitle(name: String) -> String {
    let shown = name.isEmpty ? CommonStrings.defaultChecklistName : name
    return String(
      localized: "checklists.confirm.delete.title",
      defaultValue: "Delete “\(shown)”?",
      comment: """
      Title of the alert after swiping to delete one checklist from the list of checklists. The \
      placeholder is the checklist's name, which the person typed, so it can be long; quote it the \
      way your language quotes a name. The message under it says this cannot be undone, and the \
      buttons are Cancel and Delete.
      """
    )
  }

  /// `.duplicate` is never confirmed, so it has no wording of its own; it shares delete's rather than trap.
  static func bulkConfirmationTitle(for action: ChecklistsBulkAction, count: Int) -> String {
    switch action {
    case .delete, .duplicate:
      String(
        localized: "checklists.confirm.bulkDelete.title",
        defaultValue: "Delete \(count) Checklists?",
        comment: """
        Title of the alert after Edit mode's Delete, with checklists selected. The placeholder is \
        how many will be deleted, always at least one. The message under it says this cannot be \
        undone, and the buttons are Cancel and Delete.
        """
      )
    case .reset:
      String(
        localized: "checklists.confirm.bulkReset.title",
        defaultValue: "Reset \(count) Checklists?",
        comment: """
        Title of the alert after Edit mode's Reset, with checklists selected. Reset unchecks every \
        item in them; nothing is deleted. Use the same verb as the Reset button. The placeholder is \
        how many will be reset, always at least one. The buttons are Cancel and Reset.
        """
      )
    }
  }

  static let resetAllConfirmationTitle = String(
    localized: "checklists.confirm.resetAll.title",
    defaultValue: "Reset All Checklists?",
    comment: """
    Title of the alert after the Reset All button on the list of checklists. Reset unchecks every \
    item in every checklist; nothing is deleted. Use the same verb as the Reset All button. The \
    buttons are Cancel and Reset All.
    """
  )
}
