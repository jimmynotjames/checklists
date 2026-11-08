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

  /// Where the ring stops growing: 30pt, reached at AX1. Beyond that a ring sized to the
  /// name would crowd it, taking width the name needs at the largest sizes.
  static let maximumRingScale: CGFloat = 1.5

  @ScaledMetric(relativeTo: .headline) private var ringScale: CGFloat = 1.0

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 7) {
        // Deliberately 7, not the standard 8: keeps the ring tight against the name.
        ring
        Text(checklist.name)
          .font(.headline)
          .foregroundStyle(Colors.primaryTextColor)
      }

      if let notes = checklist.notes, !notes.isEmpty {
        Text(notes)
          .font(.subheadline)
          .foregroundStyle(Colors.primaryTextColor)
          .lineLimit(3)
          // UI tests match the notes label by this identifier rather than by its rendered
          // text (see `ChecklistHeaderUITest`), so it has to stay exactly this string.
          .accessibilityIdentifier("checklistNotesLabel")
      }
    }
  }

  /// The ring, laid over one invisible line of the name's font. The line gives the ring the name's
  /// first baseline, so the stack centres it on the first line however many lines the name wraps to.
  /// The cap keeps the ring inside that line's height at every size.
  private var ring: some View {
    let scale = min(ringScale, Self.maximumRingScale)
    return Text(verbatim: " ")
      .font(.headline)
      .hidden()
      .frame(width: CircularPercentStatusIcon.diameter(for: .row, scale: scale))
      .overlay {
        StatusIconView(percentageComplete: checklist.percentageComplete, scale: scale)
          // See `CircularPercentStatusIcon.accessibilityValueText` for why the row states this.
          .accessibilityValue(
            CircularPercentStatusIcon.accessibilityValueText(forPercentageComplete: checklist.percentageComplete),
          )
      }
  }
}

extension View {
  /// A checklists-list row's background: the screen's own showing through instead of the system's
  /// row fill, except behind the open checklist's row while it is on screen beside the list, which
  /// also reads as selected.
  func openChecklistRowBackground(isOpen: Bool) -> some View {
    listRowBackground(
      Group {
        if isOpen {
          RoundedRectangle(cornerRadius: 12)
            .fill(Colors.selectedRowColor)
            .padding(.horizontal, 8)
        } else {
          Color.clear
        }
      },
    )
    .accessibilityAddTraits(isOpen ? .isSelected : [])
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

  // A long name and long notes, for checking the wrap and the ring with the canvas's Dynamic Type
  // control.
  #Preview("Long name and notes") {
    ScrollView {
      ChecklistRowView(checklist: PreviewSupport.longContentChecklist())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
  }
#endif
