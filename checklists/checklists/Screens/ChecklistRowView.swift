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
        // Deliberately 7, not the standard 8: keeps the ring tight against the name.
        StatusIconView(percentageComplete: checklist.percentageComplete)
          // See `CircularPercentStatusIcon.accessibilityValueText` for why the row states this.
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
          // text (see `ChecklistHeaderUITest`), so it has to stay exactly this string.
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
