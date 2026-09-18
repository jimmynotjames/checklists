//
//  ChecklistInfoHeaderView.swift
//  checklists
//

import UIKit

/// The checklist screen's `tableHeaderView`: status ring, name, notes, and the history caption.
///
/// Owns its subviews and their constraints; the view controller sets delegates and model text.
/// Frame-driven at its top level like `AddItemButtonTableFooterView` — the table positions both by
/// frame, and `resizeTableHeaderToFit` keeps that frame right.
final class ChecklistInfoHeaderView: UIView {
  let statusIcon = CircularPercentStatusIcon(iconType: .header)
  let nameTextField = CLTextField()
  let notesTextView = CLTextView()
  let captionView = ChecklistHistoryCaption.makeView()

  /// - Parameter showsHistoryCaption: false on the create sheet, where both caption lines could
  ///   only ever read "Never". Fixed for the view's lifetime so the header cannot grow under the
  ///   reader partway through creating a checklist.
  init(showsHistoryCaption: Bool) {
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = true
    backgroundColor = Colors.defaultBackground

    nameTextField.placeholder = "Name"
    nameTextField.font = .systemFont(ofSize: 24.0, weight: .semibold)
    nameTextField.returnKeyType = .done
    nameTextField.enablesReturnKeyAutomatically = true
    nameTextField.clearButtonMode = .whileEditing
    nameTextField.accessibilityIdentifier = "checklistNameField"
    nameTextField.accessibilityLabel = "Checklist Name: "

    notesTextView.font = .systemFont(ofSize: 16.0)
    notesTextView.backgroundColor = .clear
    notesTextView.placeholderText = "Notes"
    notesTextView.accessibilityIdentifier = "checklistNotesTextView"
    notesTextView.accessibilityLabel = "Checklist Notes: "
    // Required on both sides pins this self-sizing text view, and so this header, to its content
    // height.
    notesTextView.setContentHuggingPriority(.required, for: .vertical)
    notesTextView.setContentCompressionResistancePriority(.required, for: .vertical)

    for subview in [statusIcon, nameTextField, notesTextView] as [UIView] {
      addSubview(subview)
      subview.translatesAutoresizingMaskIntoConstraints = false
    }

    // Whichever of the two closes the height owns the bottom anchor. With no caption that is the
    // notes, and the header collapses to the height it has without the feature.
    let captionConstraints: [NSLayoutConstraint] = showsHistoryCaption
      ? ChecklistHistoryCaption.install(captionView, in: self, below: notesTextView)
      : [notesTextView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -15.0)]

    NSLayoutConstraint.activate(captionConstraints + [
      statusIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16.0),

      nameTextField.topAnchor.constraint(equalTo: topAnchor, constant: 22.0),
      nameTextField.leadingAnchor.constraint(equalTo: statusIcon.trailingAnchor, constant: 10.0),
      nameTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16.0),
      nameTextField.centerYAnchor.constraint(equalTo: statusIcon.centerYAnchor),
      nameTextField.heightAnchor.constraint(equalToConstant: 32.0),

      notesTextView.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 4.0),
      notesTextView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 8.0),
      notesTextView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16.0),
      notesTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 32.0),
    ])
  }

  /// Sizes this header for `tableView` and reinstalls it as the table's header.
  ///
  /// A `tableHeaderView` is positioned by frame and its height is read once, at assignment — there
  /// is no self-sizing equivalent of `estimatedRowHeight`. A view controller's `viewDidLoad` runs
  /// while its table is still zero-wide, so a header measured there comes out too short and draws
  /// over the first rows.
  ///
  /// Call from `viewDidLayoutSubviews`, and again whenever the content changes.
  func resize(in tableView: UITableView) {
    assert(translatesAutoresizingMaskIntoConstraints, "Measuring assumes this header owns its frame.")
    guard tableView.bounds.width > 0.0 else { return }
    let height = systemLayoutSizeFitting(
      CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
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
