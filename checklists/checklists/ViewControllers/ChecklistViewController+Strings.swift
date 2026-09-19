//
//  ChecklistViewController+Strings.swift
//  checklists
//

import Foundation

/// The detail screen's localized copy, kept beside the controller rather than in it: the
/// controller sits at the lint file-length limit.
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
}
