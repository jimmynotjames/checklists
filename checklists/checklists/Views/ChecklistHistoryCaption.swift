//
//  ChecklistHistoryCaption.swift
//  checklists
//

import Foundation
import UIKit

/// The "Updated … / Last completed …" caption under the checklist name.
///
/// Not `nonisolated` (AGENTS.md §Concurrency): it touches `UILabel` and a cached `DateFormatter`,
/// neither of which is `Sendable`.
///
/// What each line means, which actions move it, and why the shape is fixed are in
/// core-docs/persistence-design.md §"The two history stamps".
enum ChecklistHistoryCaption {
  /// Always two lines, so the header is a fixed height wherever this caption is shown.
  static let lineCount = 2

  /// Cached because a `DateFormatter` is expensive to build and this one is read on every refresh.
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    formatter.doesRelativeDateFormatting = true
    return formatter
  }()

  /// The caption's two lines, both always present — "Never" on a list that has never been run.
  ///
  /// Colons in both states because "Updated Never" is not a sentence.
  static func lines(for checklist: Checklist) -> [String] {
    [
      "Updated: \(value(of: checklist.lastUpdated))",
      // "Last completed" rather than "Completed", which alone reads as a state rather than a time —
      // and this line outlives Reset, so it must not look like a claim about the list right now.
      // "Updated" needs no such qualifier, so the two prefixes are deliberately asymmetric.
      "Last completed: \(value(of: checklist.lastCompleted))",
    ]
  }

  private static func value(of date: Date?) -> String {
    guard let date else { return "Never" }
    return dateFormatter.string(from: date)
  }

  /// The exact height the caption occupies, stated because the header measures itself once from
  /// constraints — see `install` below, which applies it.
  static var height: CGFloat {
    ceil(font.lineHeight) * CGFloat(lineCount)
  }

  private static let font: UIFont = .systemFont(ofSize: 14.0)

  /// Styles the caption label. Call once; `refresh` carries the changing part.
  static func configure(_ label: UILabel) {
    label.numberOfLines = lineCount
    // A fixed size rather than a text style, deliberately. Nothing else on this screen scales with
    // the user's text size, and a lone label that did would outgrow its neighbours at accessibility
    // sizes — core-docs/accessibility-spec.md §2.3 tracks converting the screen as a whole. 14
    // rather than the scale's nearest step up keeps 2pt between this caption and the 16pt notes.
    label.font = font
    label.textColor = .secondaryLabel
    // A test hook, not accessibility — see core-docs/accessibility-spec.md §2.4.
    label.accessibilityIdentifier = "checklistMetadataLabel"
  }

  /// Adds `label` to `header` and returns the constraints that place it, including the gap down to
  /// `notesView` — the caption owns the space it occupies on both sides.
  ///
  /// Callers that do not show a caption pin `notesView` straight to `nameField` instead, which is
  /// what collapses the header back to the height it has without this feature. Hiding the label
  /// would leave these two gaps behind.
  static func install(
    _ label: UILabel,
    in header: UIView,
    below nameField: UIView,
    above notesView: UIView
  ) -> [NSLayoutConstraint] {
    header.addSubview(label)
    label.translatesAutoresizingMaskIntoConstraints = false
    return [
      label.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 2.0),
      // Flush with the header's own left margin rather than the name field's, which is indented past
      // the status ring. 16pt is where the ring's leading edge and the notes text both already sit,
      // so the caption, the ring and the notes share one edge.
      label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16.0),
      label.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16.0),
      // Stated rather than left to `intrinsicContentSize`, like every other height in the header's
      // chain. That header is measured once, by the layout-and-reassign dance in
      // `ChecklistViewController.viewDidLoad`, and at that moment a multi-line label still reports a
      // single line — leaving the table to lay its first row underneath the header.
      label.heightAnchor.constraint(equalToConstant: height),
      notesView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 6.0),
    ]
  }

  /// Writes `checklist`'s current history into `label`. Safe to call as often as the screen likes.
  static func refresh(_ label: UILabel, for checklist: Checklist) {
    let lines = lines(for: checklist)
    label.text = lines.joined(separator: "\n")
    // Read as two sentences rather than one run-on line.
    label.accessibilityLabel = lines.joined(separator: ". ")
  }
}
