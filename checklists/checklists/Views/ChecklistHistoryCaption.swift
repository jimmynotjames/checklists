//
//  ChecklistHistoryCaption.swift
//  checklists
//

import Foundation
import UIKit

/// The "Updated … / Last completed …" caption under the checklist name.
///
/// Split out of `ChecklistViewController` so the string building is testable without standing up a
/// view controller, and so the app's one date formatter has a single home. MainActor-isolated by
/// the target default rather than `nonisolated` (AGENTS.md §Concurrency), because it touches
/// `UILabel` and a cached `DateFormatter` and neither is `Sendable`.
///
/// What each line means, and which actions move it, is in core-docs/persistence-design.md §Model.
enum ChecklistHistoryCaption {
  /// Always two lines, so the header is a fixed height wherever this caption is shown.
  ///
  /// That is what lets the checklist screen refresh it on every tick: the text changes, the layout
  /// does not, so there is no `tableHeaderView` re-measure to run and no content to shift under the
  /// reader's finger. It is also why a missing date reads as "Never" rather than dropping its line.
  static let lineCount = 2

  /// Cached because a `DateFormatter` is expensive to build and this one is read on every refresh.
  ///
  /// `doesRelativeDateFormatting` is what turns the common cases into "Today at 3:42 PM" and
  /// "Yesterday at 9:15 AM"; anything older falls back to "Sep 12, 2026 at 4:00 PM".
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    formatter.doesRelativeDateFormatting = true
    return formatter
  }()

  /// The caption's two lines.
  ///
  /// Both are always present, including as "Never". On a list that has never been run that is a
  /// fact worth stating — and keeping the shape fixed is what makes a live refresh cheap.
  ///
  /// Colons in both states because "Updated Never" is not a sentence, and because a caption that is
  /// always on screen reads as a label/value pair: only the tail changes as the user ticks, so the
  /// eye is not re-reading the whole line each time.
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

  /// The exact height the caption occupies.
  ///
  /// The header that hosts this label measures itself once, from constraints, so its subviews'
  /// heights have to be knowable up front — see the constraint that uses this in
  /// `ChecklistViewController.setUpHeaderView`.
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

  /// Writes `checklist`'s current history into `label`.
  ///
  /// Safe to call as often as the screen likes: the line count never changes, so this never alters
  /// the header's height.
  static func refresh(_ label: UILabel, for checklist: Checklist) {
    let lines = lines(for: checklist)
    label.text = lines.joined(separator: "\n")
    // Read as two sentences rather than one run-on line.
    label.accessibilityLabel = lines.joined(separator: ". ")
  }
}
