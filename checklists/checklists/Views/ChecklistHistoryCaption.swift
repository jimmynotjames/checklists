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
  /// Colons in both states because "Last updated Never" is not a sentence. Both lines share the
  /// "Last …" prefix so the pair scans as one block under the notes.
  static func lines(for checklist: Checklist) -> [String] {
    [
      "Last updated: \(value(of: checklist.lastUpdated))",
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

  /// Adds `label` to `header` as its **last** subview and returns the constraints that place it.
  ///
  /// Below the notes rather than between them and the name: the caption describes the list, so it
  /// belongs next to the list rather than wedged into the checklist's own text.
  ///
  /// Being last means the caption takes over the bottom anchor that closes the header's height —
  /// leave that on `notesView` and the chain ends above the caption, so the caption draws outside
  /// the measured height and the table lays its first row on top of it. Callers that show no
  /// caption keep that anchor on the notes instead.
  static func install(
    _ label: UILabel,
    in header: UIView,
    below notesView: UIView
  ) -> [NSLayoutConstraint] {
    header.addSubview(label)
    label.translatesAutoresizingMaskIntoConstraints = false
    return [
      // Wider than the 4pt between name and notes: sitting under a block of notes, a tighter gap
      // reads as a third paragraph of them rather than as metadata.
      label.topAnchor.constraint(equalTo: notesView.bottomAnchor, constant: 10.0),
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
      // Matches the table's `sectionHeaderHeight` below it: the two are halves of one gap between
      // the caption and the first row, so they read best at the same value.
      label.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8.0),
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
