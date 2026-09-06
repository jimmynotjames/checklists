//
//  ChecklistRowView.swift
//  checklists
//

import SwiftUI

/// One row of the checklists list: status ring, name, and up to three lines of notes.
///
/// Replaces `ChecklistCellContentView` (and the `ChecklistTableViewCell` that wrapped it).
///
/// Reading `checklist.percentageComplete` in `body` is what subscribes this row to the
/// checklist's items through SwiftData's Observation support: when an item's status changes
/// on another screen — the detail screen's checkboxes, or "Reset All" — the ring here
/// redraws on its own. The UIKit version had no such link, which is why every one of those
/// paths had to remember to call `reloadData`.
struct ChecklistRowView: View {
  let checklist: Checklist

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 7) {
        // 7pt, not the standard 8: carried over verbatim from the cell's visual-format
        // string ("[statusIcon]-7-[nameLabel]"), where it was a deliberate tightening.
        StatusIconView(percentageComplete: checklist.percentageComplete)
        Text(checklist.name)
          .font(.headline) // Was .systemFont(ofSize: 18.0, weight: .semibold).
          .lineLimit(1)
      }

      if let notes = checklist.notes, !notes.isEmpty {
        Text(notes)
          .font(.subheadline) // Was .systemFont(ofSize: 15.0).
          .lineLimit(3)
          // UI tests match the notes label by this identifier rather than by its rendered
          // text (see `checklistUITest`), so it has to stay exactly this string.
          .accessibilityIdentifier("checklistNotesLabel")
      }
    }
  }
}
