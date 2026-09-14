//
//  ChecklistRowView.swift
//  checklists
//

import SwiftUI

/// One row of the checklists list: status ring, name, and up to three lines of notes.
///
/// Reading `checklist.percentageComplete` in `body` is what subscribes this row to the
/// checklist's items through SwiftData's Observation support: when an item's status changes
/// on another screen — the detail screen's checkboxes, or "Reset All" — the ring here
/// redraws on its own.
struct ChecklistRowView: View {
  let checklist: Checklist

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 7) {
        // Deliberately 7, not the standard 8: keeps the ring tight against the name (matches
        // the pre-SwiftUI design; see PR #136).
        StatusIconView(percentageComplete: checklist.percentageComplete)
          // Declared here, not just left to the wrapped `CircularPercentStatusIcon`: the row is a
          // `Button`, and SwiftUI folds a button's content into one element whose value is whatever
          // the merge happens to pick up from the hosted UIView. Stating the value on this side
          // makes "Morning Routine, Checklist 83 percent complete" the row's contract instead of a
          // by-product of the icon leaving its `accessibilityLabel` nil.
          //
          // Only the value is declared. The grouping is left exactly as it is: `checklistNotesLabel`
          // and the icon are both addressed as elements *inside* the row's cell by `checklistUITest`,
          // so collapsing the children here would take those away for no accessibility gain.
          .accessibilityValue(
            CircularPercentStatusIcon.accessibilityValueText(forPercentageComplete: checklist.percentageComplete)
          )
        Text(checklist.name)
          .font(.headline)
          .lineLimit(1)
      }

      if let notes = checklist.notes, !notes.isEmpty {
        Text(notes)
          .font(.subheadline)
          .lineLimit(3)
          // UI tests match the notes label by this identifier rather than by its rendered
          // text (see `checklistUITest`), so it has to stay exactly this string.
          .accessibilityIdentifier("checklistNotesLabel")
      }
    }
  }
}

#if DEBUG
  #Preview("Untouched") {
    ChecklistRowView(checklist: PreviewSupport.checklist(id: SampleData.preTripId))
      .padding()
  }

  #Preview("Partly done") {
    ChecklistRowView(checklist: PreviewSupport.checklist(id: SampleData.weekendGetawayId))
      .padding()
  }

  #Preview("Nearly done") {
    ChecklistRowView(checklist: PreviewSupport.checklist(id: SampleData.morningRoutineId))
      .padding()
  }
#endif
