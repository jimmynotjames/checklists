//
//  Analytics+DomainExtensions.swift
//  checklists
//

import UIKit

/// Maps a device orientation to the `orientation` property value, or `nil` when the rotation is
/// not one this app reports.
///
/// Face-up and face-down fire the same notification as a real rotation but say nothing about how
/// the app is being held, so they are filtered rather than bucketed into one of the two values.
///
/// Upside-down portrait maps to `portrait`. The app does not support that orientation, but the
/// notification can still arrive, and calling it portrait is more honest than dropping it.
///
/// Pure and `nonisolated` so it can be tested without a device or a running app.
nonisolated func orientationAnalyticsValue(_ orientation: UIDeviceOrientation) -> String? {
  if orientation.isPortrait { return "portrait" }
  if orientation.isLandscape { return "landscape" }
  return nil
}

/// Buckets a count for use as a **profile** property (§9.3).
///
/// Events carry raw counts; profiles carry buckets. That is not a contradiction — cohorts are
/// built from profiles, and a cohort of "people with exactly 7 checklists" is not useful.
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
/// An enum rather than two string constants so a call site cannot invent a third value.
nonisolated enum ChecklistDuplicationSource: String {
  case menu
  case swipe
}

/// Where the checked items went — the `destination` property on `checklist_items_copied`.
///
/// An enum for the same reason as `ChecklistDuplicationSource` above. The raw values are spelled
/// out rather than left to the case names: these *are* the analytics vocabulary, and a Swift
/// rename should not be able to change what the dashboards group by.
nonisolated enum CheckedItemsCopyDestination: String {
  case newChecklist = "new"
  case existingChecklist = "existing"
}

extension Checklist {
  /// The properties `checklist_viewed` carries.
  ///
  /// Assembled here rather than at the call site so the PII boundary is in one reviewable place:
  /// the checklist's **name** is sent (§4.4) and the length of its notes, but no note text and
  /// nothing at all from the items beyond how many there are and how many carry notes.
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
