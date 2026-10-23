//
//  ChecklistInfoHeaderView.swift
//  checklists
//

import UIKit

/// The checklist screen's `tableHeaderView`: status ring, name, notes, and the history caption.
///
/// Owns its subviews and their constraints; the view controller sets delegates and model text.
/// Frame-driven at its top level like `AddItemButtonTableFooterView` — the table positions both by
/// frame, and `resize(in:)` keeps that frame right.
final class ChecklistInfoHeaderView: UIView {
  let statusIcon = CircularPercentStatusIcon(iconType: .header)
  let nameTextField = CLTextField()
  let notesTextView = CLTextView()
  let captionView = ChecklistHistoryCaption.makeView()

  /// The name's size at AX3, where it stops growing: past that a name of a few words no longer fits
  /// the width of a phone, and the field is a single line. Up to AX4 it stays at least the size of
  /// the notes below it.
  private static let maximumNamePointSize: CGFloat = 45.0

  /// Restated on each text-size change; nil on the create sheet, which has no caption.
  private var captionHeightConstraint: NSLayoutConstraint?

  /// - Parameter showsHistoryCaption: false on the create sheet, where both caption lines could
  ///   only ever read "Never". Fixed for the view's lifetime so the header cannot grow under the
  ///   reader partway through creating a checklist.
  init(showsHistoryCaption: Bool) {
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = true
    backgroundColor = Colors.defaultBackground

    nameTextField.placeholder = String(localized: "checklist.name.placeholder", defaultValue: "Name", comment: "Placeholder of the checklist name field in the detail header.")
    nameTextField.font = UIFontMetrics(forTextStyle: .title2).scaledFont(
      for: .systemFont(ofSize: 24.0, weight: .semibold),
      maximumPointSize: Self.maximumNamePointSize,
    )
    nameTextField.adjustsFontForContentSizeCategory = true
    nameTextField.returnKeyType = .done
    nameTextField.enablesReturnKeyAutomatically = true
    nameTextField.clearButtonMode = .whileEditing
    nameTextField.accessibilityIdentifier = "checklistNameField"
    nameTextField.accessibilityLabel = String(
      localized: "checklist.name.accessibilityLabel",
      defaultValue: "Checklist Name: ",
      comment: "VoiceOver label read before the checklist name field. Keep the trailing space and colon.",
    )
    // The screen's heading, since the bar shows no title until the name scrolls under it.
    nameTextField.accessibilityTraits.insert(.header)

    notesTextView.font = .preferredFont(forTextStyle: .callout)
    notesTextView.adjustsFontForContentSizeCategory = true
    notesTextView.backgroundColor = .clear
    // The gap below the notes, inside the field so a tap just under the last line still lands on
    // it. Wider than the gap above: under a block of notes a tighter one makes the history caption
    // read as a third paragraph of them rather than as metadata.
    notesTextView.textContainerInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 10.0, right: 0.0)
    notesTextView.placeholderText = CommonStrings.notesPlaceholder
    notesTextView.accessibilityIdentifier = "checklistNotesTextView"
    notesTextView.accessibilityLabel = String(
      localized: "checklist.notes.accessibilityLabel",
      defaultValue: "Checklist Notes: ",
      comment: "VoiceOver label read before the checklist notes field. Keep the trailing space and colon.",
    )
    // Required on both sides pins this self-sizing text view, and so this header, to its content
    // height.
    notesTextView.setContentHuggingPriority(.required, for: .vertical)
    notesTextView.setContentCompressionResistancePriority(.required, for: .vertical)

    for subview in [statusIcon, nameTextField, notesTextView] as [UIView] {
      addSubview(subview)
      subview.translatesAutoresizingMaskIntoConstraints = false
    }

    let column = addReadableColumnGuide()

    // Whichever of the two closes the height owns the bottom anchor. With no caption that is the
    // notes, and the header collapses to the height it has without the feature.
    let captionConstraints: [NSLayoutConstraint]
    if showsHistoryCaption {
      let installed = ChecklistHistoryCaption.install(captionView, in: self, column: column, below: notesTextView)
      captionConstraints = installed.constraints
      captionHeightConstraint = installed.height
    } else {
      captionConstraints = [notesTextView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5.0)]
    }

    // Both fields meet Apple's minimum touch target with the slack inside them rather than around
    // them, so a near-miss still lands on a field.
    NSLayoutConstraint.activate(captionConstraints + [
      statusIcon.leadingAnchor.constraint(equalTo: column.leadingAnchor, constant: 16.0),

      // A text field centres its text vertically, so it stays on the status ring's centre line, and
      // grows evenly around text larger than the touch target.
      nameTextField.topAnchor.constraint(equalTo: topAnchor, constant: 16.0),
      nameTextField.leadingAnchor.constraint(equalTo: statusIcon.trailingAnchor, constant: 10.0),
      nameTextField.trailingAnchor.constraint(equalTo: column.trailingAnchor, constant: -16.0),
      nameTextField.centerYAnchor.constraint(equalTo: statusIcon.centerYAnchor),
      nameTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44.0),

      // Abutting: the name field's own slack is the gap between the two.
      notesTextView.topAnchor.constraint(equalTo: nameTextField.bottomAnchor),
      notesTextView.leadingAnchor.constraint(equalTo: column.leadingAnchor, constant: 16.0),
      notesTextView.trailingAnchor.constraint(equalTo: column.trailingAnchor, constant: -16.0),
      notesTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44.0),
    ])

    // The fonts rescale themselves; the caption's stated height has to be told. Re-measuring the
    // header is the view controller's job, since only it knows the table.
    registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: Self, _) in
      view.captionHeightConstraint?.constant = ChecklistHistoryCaption.height(compatibleWith: view.traitCollection)
    }
  }

  /// Where the name's text ends, in this view's coordinates: the field centres one line of it.
  var nameTextBottom: CGFloat {
    nameTextField.frame.midY + (nameTextField.font?.lineHeight ?? 0.0) / 2.0
  }

  /// Sizes this header for `tableView` and reinstalls it as the table's header.
  ///
  /// A `tableHeaderView` is positioned by frame and its height is read once, at assignment — there
  /// is no self-sizing equivalent of `estimatedRowHeight`. A view controller's `viewDidLoad` runs
  /// while its table is still zero-wide, so a header measured there comes out too short and draws
  /// over the first rows.
  ///
  /// Call from `viewDidLayoutSubviews`, and again whenever the content or the text size changes.
  func resize(in tableView: UITableView) {
    assert(translatesAutoresizingMaskIntoConstraints, "Measuring assumes this header owns its frame.")
    guard tableView.bounds.width > 0.0 else { return }
    let height = systemLayoutSizeFitting(
      CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel,
    ).height
    // Reassigning is what makes the table re-read the height, and it triggers another layout pass,
    // so only do it on a real change or this recurses. The width term covers rotation.
    guard abs(height - frame.height) > 0.5 || abs(tableView.bounds.width - frame.width) > 0.5 else { return }
    frame = CGRect(x: 0.0, y: 0.0, width: tableView.bounds.width, height: height)
    tableView.tableHeaderView = self
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError()
  }
}
