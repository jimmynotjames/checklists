//
//  ChecklistsView+Strings.swift
//  checklists
//

import Foundation

/// What the list of checklists says to VoiceOver after a delete, a duplicate or a reset.
extension ChecklistsView {
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
