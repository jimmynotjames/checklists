//
//  ChecklistsKeyboardShortcuts.swift
//  checklists
//

import SwiftUI

/// ChecklistsView's ⌘N, as an unseen button so it carries a title for the iPad's ⌘ list: the bar's
/// Add is artwork, titled only for VoiceOver. The screen's other shortcuts sit on its own buttons.
struct ChecklistsNewChecklistShortcut: View {
  /// Off under ChecklistScreen, whose own ⌘N adds an item, and under a sheet.
  let isEnabled: Bool
  let newChecklist: () -> Void

  @Environment(\.analytics) private var analytics

  var body: some View {
    Button(Self.title) {
      analytics.trackShortcut(.newChecklist)
      newChecklist()
    }
    .keyboardShortcut(isEnabled ? KeyboardShortcut("n") : nil)
    .frame(width: 0, height: 0)
    .opacity(0)
    .accessibilityHidden(true)
  }

  private static let title = String(
    localized: "checklists.shortcut.newChecklist",
    defaultValue: "New Checklist",
    comment: """
    Name of the ⌘N keyboard shortcut on the screen listing every checklist, shown in the list of \
    shortcuts an iPad shows while ⌘ is held. Creates a checklist, like the Add button. Title case, \
    like a menu command.
    """,
  )
}
