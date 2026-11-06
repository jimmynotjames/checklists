//
//  Analytics+DomainExtensions.swift
//  checklists
//

import Foundation

/// Buckets a count for the `checklists_count_bucket` **profile** property. Events carry raw counts;
/// cohorts are built from profiles, where a bucket is what is useful.
nonisolated func checklistsCountBucket(_ count: Int) -> String {
  switch count {
  case ..<1: "0"
  case 1: "1"
  case 2 ... 3: "2-3"
  case 4 ... 7: "4-7"
  default: "8+"
  }
}

/// Which affordance a duplication was started from — the `source` property on
/// `checklist_duplicated`.
///
/// An enum rather than string constants so a call site cannot invent another value. `menu` is the
/// detail screen's "•••" menu; `contextMenu` is a checklists-list row's long-press or right-click.
nonisolated enum ChecklistDuplicationSource: String {
  case menu
  case swipe
  case contextMenu = "context_menu"
}

/// Where the checked items went — the `destination` property on `checklist_items_copied` and
/// `checklist_items_moved`.
///
/// An enum for the same reason as `ChecklistDuplicationSource` above. The raw values are spelled
/// out rather than left to the case names: these *are* the analytics vocabulary, and a Swift
/// rename should not be able to change what the dashboards group by.
nonisolated enum CheckedItemsCopyDestination: String {
  case newChecklist = "new"
  case existingChecklist = "existing"
}

/// Which Edit mode toolbar action ran — the `bulk_action` property on
/// `checklists_bulk_action_performed`. The raw values are the case names, pinned by
/// `AnalyticsNamesTests` so a rename cannot silently change what dashboards group by.
nonisolated enum ChecklistsBulkAction: String {
  case delete
  case duplicate
  case reset
}

/// Which hardware-keyboard shortcut ran — the `shortcut` property on `keyboard_shortcut_used`.
/// Spelled out for the same reason as `CheckedItemsCopyDestination`.
nonisolated enum KeyboardShortcutName: String, CaseIterable {
  case newChecklist = "new_checklist"
  case done
  case newItem = "new_item"
  case toggleItem = "toggle_item"
  case duplicateItem = "duplicate_item"
  case deleteItem = "delete_item"
}

extension AnalyticsClient {
  func trackShortcut(_ shortcut: KeyboardShortcutName) {
    track(AnalyticsEvent.keyboardShortcutUsed, properties: [AnalyticsProperty.shortcut: shortcut.rawValue])
  }
}

extension Checklist {
  /// The properties `checklist_viewed` carries.
  ///
  /// Assembled here rather than at the call site so the PII boundary is in one reviewable place:
  /// the checklist's **name** is sent (analytics-spec.md §Free-text exception) and the length of
  /// its notes, but no note text and nothing from the items beyond two counts.
  var analyticsViewedProperties: [String: any Sendable] {
    [
      AnalyticsProperty.checklistName: AnalyticsText.truncated(name),
      AnalyticsProperty.notesLength: notes?.count ?? 0,
      AnalyticsProperty.itemsCount: items.count,
      AnalyticsProperty.itemsWithNotesCount: items.count { item in
        guard let notes = item.notes else { return false }
        return !notes.isEmpty
      },
    ]
  }
}
