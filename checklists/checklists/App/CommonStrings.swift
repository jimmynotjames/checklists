//
//  CommonStrings.swift
//  checklists
//

import Foundation

/// Catalog keys used on more than one screen, declared once each.
///
/// A key's `defaultValue` and its translator comment are part of its contract: the comment is the
/// only context a translator ever sees, and `defaultValue` is what ships if the key is missing from
/// the catalog. Restating either at each call site lets two screens disagree about one string —
/// `common.action.cancel` already carried two different comments before this type existed.
///
/// Only genuinely shared copy belongs here. A string used on one screen stays on that screen, where
/// its comment can describe that screen; `common.*` means the same words in the same sense
/// everywhere, which is also why translating it once is safe.
nonisolated enum CommonStrings {
  static let cancel = String(
    localized: "common.action.cancel",
    defaultValue: "Cancel",
    comment: "Dismisses a confirmation alert without doing anything."
  )

  static let delete = String(
    localized: "common.action.delete",
    defaultValue: "Delete",
    comment: "Destructive action: removes a checklist. Swipe action and confirmation button."
  )

  static let done = String(
    localized: "common.action.done",
    defaultValue: "Done",
    comment: "Keyboard accessory button that ends editing."
  )

  static let notesPlaceholder = String(
    localized: "common.notes.placeholder",
    defaultValue: "Notes",
    comment: "Placeholder of the optional notes field on an item and on a checklist header."
  )

  static let settingsTitle = String(
    localized: "common.settings.title",
    defaultValue: "Settings",
    comment: "Title of the Settings screen and the main-menu row that opens it."
  )

  /// Under the delete-checklist and reset-all confirmations on the list screen, and under the
  /// delete confirmation reached from the detail screen's overflow menu. Keyed under `checklists.`
  /// rather than `common.` because the list screen is where it first appeared and renaming a key
  /// costs every locale a re-translation.
  static let irreversibleConfirmation = String(
    localized: "checklists.confirm.irreversible",
    defaultValue: "Are you sure? This cannot be undone.",
    comment: "Alert message under both the delete-checklist and the reset-all confirmations."
  )
}
