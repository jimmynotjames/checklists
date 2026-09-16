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
  /// Cached because a `DateFormatter` is expensive to build and this one is read during header
  /// layout.
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

  /// The caption as zero, one, or two lines.
  ///
  /// A checklist being created right now has no history to report: "Updated moments ago" is noise,
  /// and it has never been completed. A checklist that has been authored but never ticked has none
  /// either. Both cases return `[]`, and the header closes up around the gap — see
  /// `ChecklistViewController.setUpHeaderView`.
  static func lines(for checklist: Checklist, isNewChecklist: Bool) -> [String] {
    guard !isNewChecklist else { return [] }
    var lines: [String] = []
    if let lastUpdated = checklist.lastUpdated {
      lines.append("Updated \(dateFormatter.string(from: lastUpdated))")
    }
    // "Last completed" rather than "Completed", which alone reads as a state rather than a time —
    // and this line outlives Reset, so it must not look like a claim about the list right now.
    // "Updated" needs no such qualifier, so the two prefixes are deliberately asymmetric.
    if let lastCompleted = checklist.lastCompleted {
      lines.append("Last completed \(dateFormatter.string(from: lastCompleted))")
    }
    return lines
  }

  /// The exact height `lineCount` lines of the caption font occupy.
  ///
  /// The header that hosts this label measures itself once, from constraints, so its subviews'
  /// heights have to be knowable up front — see the constraint that uses this in
  /// `ChecklistViewController.setUpHeaderView`.
  static func height(forLineCount lineCount: Int) -> CGFloat {
    ceil(font.lineHeight) * CGFloat(lineCount)
  }

  private static let font: UIFont = .systemFont(ofSize: 14.0)

  /// Applies `lines` to the header's caption label.
  static func configure(_ label: UILabel, with lines: [String]) {
    label.numberOfLines = lines.count
    // A fixed size rather than a text style, deliberately. Nothing else on this screen scales with
    // the user's text size, and a lone label that did would outgrow its neighbours at accessibility
    // sizes — core-docs/accessibility-spec.md §2.3 tracks converting the screen as a whole. 14
    // rather than the scale's nearest step up keeps 2pt between this caption and the 16pt notes.
    label.font = font
    label.textColor = .secondaryLabel
    label.text = lines.joined(separator: "\n")
    // Read as two sentences rather than one run-on line.
    label.accessibilityLabel = lines.joined(separator: ". ")
    // A test hook, not accessibility — see core-docs/accessibility-spec.md §2.4.
    label.accessibilityIdentifier = "checklistMetadataLabel"
  }
}
