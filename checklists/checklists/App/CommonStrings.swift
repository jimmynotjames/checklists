//
//  CommonStrings.swift
//  checklists
//

import Foundation

/// Catalog keys used on more than one screen, declared once each.
///
/// A key's `defaultValue` and its translator comment are part of its contract: the comment is the
/// only context a translator ever sees, and `defaultValue` is what ships if the key is missing from
/// the catalog. Restating either at each call site lets two screens disagree about one string.
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
    comment: "Destructive action: removes a checklist or an item. Swipe action, Edit mode toolbar button on the list of checklists, and confirmation button."
  )

  static let done = String(
    localized: "common.action.done",
    defaultValue: "Done",
    comment: """
    Ends editing: the button above the keyboard when naming a new checklist to copy or move \
    checked items into, the nav bar button that leaves Edit mode on the \
    list of checklists (it reads Edit until tapped), and the nav bar button that leaves Reorder \
    Items mode on a checklist's screen.
    """
  )

  static let duplicate = String(
    localized: "common.action.duplicate",
    defaultValue: "Duplicate",
    comment: "Makes a copy of a checklist or an item. Swipe action, and Edit mode toolbar button on the list of checklists; VoiceOver reads it as the button's name."
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

  /// Written into the store as a checklist's name, not shown as a label, so it stays in whatever
  /// language the device had when it was saved. Lives here rather than on the detail screen because
  /// `ChecklistCopyNaming` needs the same fallback and must not reach into a view controller for it.
  static let defaultChecklistName = String(
    localized: "checklist.defaultName",
    defaultValue: "untitled checklist",
    comment: "Name stored for a checklist saved with an empty name field. Lowercase in English; it is data once saved."
  )

  /// Keyed under `checklists.` rather than `common.` because renaming a key costs every locale a
  /// re-translation.
  static let irreversibleConfirmation = String(
    localized: "checklists.confirm.irreversible",
    defaultValue: "Are you sure? This cannot be undone.",
    comment: "Alert message under the delete, reset and reset-all confirmations on the checklist list, and under the delete-checklist confirmation on a checklist's own screen."
  )
}
