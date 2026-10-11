//
//  ChecklistHistoryCaption.swift
//  checklists
//

import Foundation
import UIKit

/// The "Last updated … / Last completed …" caption under the checklist's notes.
///
/// Not `nonisolated` (AGENTS.md §Concurrency): it touches `UIView` and a cached `DateFormatter`,
/// neither of which is `Sendable`.
///
/// What each line means and which actions move it:
/// `persistence-design.md §The two history stamps`.
enum ChecklistHistoryCaption {
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    formatter.doesRelativeDateFormatting = true
    return formatter
  }()

  private static let font: UIFont = .systemFont(ofSize: 14.0)

  /// Always two, so the header is a fixed height wherever the caption shows.
  private static let lineCount = 2

  /// The caption's two lines, both always present — "Never" on a list that has never been run.
  static func lines(for checklist: Checklist) -> [String] {
    [
      String(
        localized: "checklist.history.lastUpdated",
        defaultValue: "Last updated: \(value(of: checklist.lastUpdated))",
        comment: "Caption line under a checklist's notes; the placeholder is a formatted date and time, or the word for Never."
      ),
      String(
        localized: "checklist.history.lastCompleted",
        defaultValue: "Last completed: \(value(of: checklist.lastCompleted))",
        comment: "Caption line under a checklist's notes; the placeholder is a formatted date and time, or the word for Never."
      ),
    ]
  }

  private static func value(of date: Date?) -> String {
    guard let date else {
      return String(
        localized: "checklist.history.never",
        defaultValue: "Never",
        comment: "Stands in for the date in the Last updated / Last completed caption when the checklist has never been touched."
      )
    }
    return dateFormatter.string(from: date)
  }

  /// A caption view for `lines(for:)`, ready to be placed by `install`.
  ///
  /// A row per line rather than one two-line label: a label clamped to two lines drops the second
  /// one whenever the first has to wrap, which a long date in a verbose locale can do on a narrow
  /// phone. Each row truncates on its own instead, so neither line can silently disappear.
  static func makeView() -> UIStackView {
    let view = UIStackView(arrangedSubviews: (0 ..< lineCount).map { _ in makeLineLabel() })
    view.axis = .vertical
    view.isAccessibilityElement = true
    // One element reading both lines, and static text is what it is — without the trait VoiceOver
    // announces an untyped group, and the UI tests stop finding it among `staticTexts`.
    view.accessibilityTraits = .staticText
    // A test hook, not accessibility — see `accessibility-spec.md §Identifiers are test hooks`.
    view.accessibilityIdentifier = "checklistMetadataLabel"
    return view
  }

  private static func makeLineLabel() -> UILabel {
    let label = UILabel()
    label.numberOfLines = 1
    label.lineBreakMode = .byTruncatingTail
    // A fixed size rather than a text style: nothing else on this screen scales with the user's text
    // size, so a lone label that did would outgrow its neighbours — `accessibility-spec.md §Dynamic Type`.
    label.font = font
    label.textColor = .secondaryLabel
    return label
  }

  /// Writes `checklist`'s current history into a view from `makeView`.
  static func refresh(_ view: UIStackView, for checklist: Checklist) {
    let lines = lines(for: checklist)
    for (label, line) in zip(view.arrangedSubviews.compactMap { $0 as? UILabel }, lines) {
      label.text = line
    }
    // Read as two sentences rather than one run-on line.
    view.accessibilityLabel = lines.joined(separator: ". ")
  }

  /// Adds `view` to `header` and returns the constraints placing it below `notesView`, inside
  /// `column`, the header's content column.
  ///
  /// The caption owns the bottom anchor that closes the header's height, and so its own height is
  /// stated rather than intrinsic — every height in that chain is a constant.
  static func install(_ view: UIStackView, in header: UIView, column: UILayoutGuide, below notesView: UIView) -> [NSLayoutConstraint] {
    header.addSubview(view)
    view.translatesAutoresizingMaskIntoConstraints = false
    return [
      // Flush: the gap above the caption is the notes view's bottom inset, so it stays tappable.
      view.topAnchor.constraint(equalTo: notesView.bottomAnchor),
      // The column's leading edge, where the status ring also sits.
      view.leadingAnchor.constraint(equalTo: column.leadingAnchor, constant: 16.0),
      view.trailingAnchor.constraint(equalTo: column.trailingAnchor, constant: -16.0),
      view.heightAnchor.constraint(equalToConstant: height),
      // Matches the table's `sectionHeaderHeight`, the other half of the gap down to the first row.
      view.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8.0),
    ]
  }

  /// The exact height the caption occupies.
  static var height: CGFloat {
    ceil(font.lineHeight) * CGFloat(lineCount)
  }
}
