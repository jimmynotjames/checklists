//
//  ItemContentView.swift
//  checklists
//
//  Created by Jimmy Ho on 5/19/19.
//

import UIKit

/// Apple's minimum touch target, for both fields. Their text insets fill it out, so a tap above or
/// below the text still lands on the field.
private var minNameFieldHeight: CGFloat = 44.0
private var minNotesTextViewHeight: CGFloat = 44.0

protocol ItemContentViewDelegate: AnyObject {
  func itemContentViewCheckboxButtonTapped(_ itemContentView: ItemContentView)
  func itemContentViewNameFieldDidBeginEditing(_ itemContentView: ItemContentView)
  func itemContentViewDidFinishEditing(_ itemContentView: ItemContentView)
  func itemContentViewHeightUpdated(_ itemContentView: ItemContentView)
  func itemContentView(_ itemContentView: ItemContentView, nameFieldUpdatedWith name: String)
  func itemContentView(_ itemContentView: ItemContentView, notesFieldUpdatedWith notes: String)

  func itemContentViewDidReturnOnNameField(_ itemContentView: ItemContentView)
  func itemContentViewDidBackspaceEmpty(_ itemContentView: ItemContentView)
}

class ItemContentView: UIView {
  var item: Item? {
    didSet {
      if let item {
        nameTextView.text = item.name
        if let notes = item.notes {
          notesTextView.text = notes
        } else {
          notesTextView.text = ""
        }
        updateCheckedStatus()
        refreshHeight()
      } else {
        checkboxButton.setCheckboxState(with: .unchecked)
        nameTextView.text = ""
        notesTextView.text = ""
      }
    }
  }

  weak var delegate: ItemContentViewDelegate?

  var isEditing: Bool {
    nameTextView.isFirstResponder || notesTextView.isFirstResponder
  }

  private lazy var checkboxButton: CheckboxButton = {
    let button = CheckboxButton()
    button.addTarget(self, action: #selector(checkboxButtonTapped(sender:)), for: .touchUpInside)
    return button
  }()

  private lazy var nameTextView: CLTextView = {
    let textView = CLTextView()
    textView.delegate = self
    textView.font = UIFont.systemFont(ofSize: 22.0, weight: .regular)
    // The row's top margin and the gap down to the notes, inside the field rather than around it.
    textView.textContainerInset = UIEdgeInsets(top: 10.0, left: 0.0, bottom: 8.0, right: 0.0)
    textView.inputAccessoryButtonTappedAction = {
      textView.resignFirstResponder()
    }
    textView.returnKeyType = .next
    textView.accessibilityIdentifier = "itemNameTextView"
    textView.accessibilityLabel = String(
      localized: "item.name.accessibilityLabel",
      defaultValue: "checklist item: ",
      comment: "VoiceOver label read before an item's name in the editable item row. Keep the trailing space and colon."
    )
    return textView
  }()

  private lazy var notesTextView: CLTextView = {
    let textView = CLTextView()
    textView.placeholderText = CommonStrings.notesPlaceholder
    textView.font = UIFont.systemFont(ofSize: 15.0)
    // The row's bottom margin, inside the field rather than below it; see `containerBottomConstraint`.
    textView.textContainerInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 4.0, right: 0.0)
    textView.inputAccessoryButtonTappedAction = {
      textView.resignFirstResponder()
    }
    textView.returnKeyType = .default
    textView.delegate = self
    textView.accessibilityIdentifier = "itemNotesTextView"
    textView.accessibilityLabel = String(
      localized: "item.notes.accessibilityLabel",
      defaultValue: "optional notes: ",
      comment: "VoiceOver label read before an item's notes in the editable item row. Keep the trailing space and colon."
    )
    return textView
  }()

  private let containerView = UIView()

  private lazy var notesTextViewHeightConstraint: NSLayoutConstraint = notesTextView.heightAnchor.constraint(equalToConstant: 0.0)
  /// The row's bottom margin while the notes field is hidden. A shown notes field takes it as its
  /// bottom inset instead, so it stays tappable.
  private lazy var containerBottomConstraint: NSLayoutConstraint = bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: notesTextView.textContainerInset.bottom)

  private var wasInputFieldTapped: Bool = false

  convenience init() {
    self.init(frame: .zero)
  }

  override init(frame: CGRect) {
    super.init(frame: frame)

    addSubview(containerView)
    containerView.addSubview(notesTextView)
    containerView.addSubview(nameTextView)
    addSubview(checkboxButton) // checkbox needs to be in front due to overlapping tap targets, so prefer checkbox.

    installConstraints()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("This init() not supported.")
  }

  func refreshHeight() {
    updateTextViewHeight(isExpanded: item?.notes?.count ?? 0 > 0)
  }

  func updateTextViewHeight(isExpanded: Bool) {
    notesTextViewHeightConstraint.isActive = false
    if isExpanded {
      notesTextViewHeightConstraint = notesTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: minNotesTextViewHeight)
    } else {
      notesTextViewHeightConstraint = notesTextView.heightAnchor.constraint(equalToConstant: 0.0)
    }
    notesTextViewHeightConstraint.isActive = true
    containerBottomConstraint.constant = isExpanded ? 0.0 : notesTextView.textContainerInset.bottom
  }

  func startEditing() {
    _ = nameTextView.becomeFirstResponder()
  }

  /// Reorder Items mode: the row shows as usual but takes no touches, and its text cannot be
  /// edited. `isEditable` as well, because a VoiceOver double-tap does not go through hit-testing.
  func setReordering(_ reordering: Bool) {
    isUserInteractionEnabled = !reordering
    nameTextView.isEditable = !reordering
    notesTextView.isEditable = !reordering
  }

  /// Put on every element VoiceOver can land on in the row: the row itself is not one, and custom
  /// actions are not inherited from a container.
  func setAccessibilityMoveActions(_ actions: [UIAccessibilityCustomAction]) {
    checkboxButton.accessibilityCustomActions = actions
    nameTextView.accessibilityCustomActions = actions
    notesTextView.accessibilityCustomActions = actions
  }

  /// Where VoiceOver focus goes after the row is moved.
  var accessibilityFocusTarget: UIView {
    nameTextView
  }

  func updateCheckedStatus() {
    guard let status = item?.status else { return }
    checkboxButton.setCheckboxState(with: status)
    let textColor = status == .checked ? Colors.inactiveText : Colors.primaryText
    nameTextView.textColor = textColor
    notesTextView.textColor = textColor
  }

  /// Detects taps between input fields (to decide whether to collapse when notes are empty);
  /// `endEditing` alone can't distinguish that case from focus leaving entirely.
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let view = super.hitTest(point, with: event)
    // A text view hands back one of its own internal subviews, never itself, so this asks whether
    // the touch landed anywhere inside a field rather than exactly on it.
    wasInputFieldTapped = view.map { $0.isDescendant(of: nameTextView) || $0.isDescendant(of: notesTextView) } ?? false
    return view
  }

  private func installConstraints() {
    let views = ["itemContentView": self, // No actual effect, except to suppress intermediate unsatisfiable constraint warnings.
                 "checkboxButton": checkboxButton,
                 "containerView": containerView,
                 "nameTextView": nameTextView,
                 "notesTextView": notesTextView]
    views.forEach { $0.value.translatesAutoresizingMaskIntoConstraints = false }

    nameTextView.setContentCompressionResistancePriority(.required, for: .vertical)
    nameTextView.setContentHuggingPriority(.required, for: .vertical)

    NSLayoutConstraint.activate(
      [NSLayoutConstraint.constraints(withVisualFormat: "H:|-2-[checkboxButton]-(-4)-[containerView]-16-|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "V:|[checkboxButton]", options: [], metrics: nil, views: views),

       [containerView.topAnchor.constraint(equalTo: topAnchor), containerBottomConstraint],
       NSLayoutConstraint.constraints(withVisualFormat: "V:|[nameTextView][notesTextView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|[nameTextView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|[notesTextView]|", options: [], metrics: nil, views: views),
       [nameTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: minNameFieldHeight), notesTextViewHeightConstraint]].flatMap(\.self)
    )
  }

  @objc func checkboxButtonTapped(sender _: UIButton) {
    delegate?.itemContentViewCheckboxButtonTapped(self)
  }

  private func finishEditingViewIfNecessary() {
    if !wasInputFieldTapped {
      refreshHeight()
      delegate?.itemContentViewDidFinishEditing(self)
    }
  }
}

extension ItemContentView: UITextViewDelegate {
  func textViewDidBeginEditing(_ textView: UITextView) {
    if textView == nameTextView {
      delegate?.itemContentViewNameFieldDidBeginEditing(self)
    }
    wasInputFieldTapped = false
  }

  func textViewDidEndEditing(_ textView: UITextView) {
    switch textView {
    case nameTextView:
      delegate?.itemContentView(self, nameFieldUpdatedWith: textView.text)
    case notesTextView:
      delegate?.itemContentView(self, notesFieldUpdatedWith: textView.text)
    default:
      assertionFailure()
    }
    finishEditingViewIfNecessary()
  }

  func textViewDidChange(_: UITextView) {
    delegate?.itemContentViewHeightUpdated(self)
  }

  func textView(_ textView: UITextView, shouldChangeTextIn _: NSRange, replacementText text: String) -> Bool {
    if text == "\n", textView == nameTextView {
      delegate?.itemContentViewDidReturnOnNameField(self)
      return false
    }
    if text.isEmpty, textView.text.isEmpty { // Assume someone backspaced on empty field
      if textView == nameTextView, !notesTextView.hasText { // Both fields should be empty to call.
        delegate?.itemContentViewDidBackspaceEmpty(self)
        return false
      } else if textView == notesTextView {
        nameTextView.becomeFirstResponder()
        return false
      }
    }
    return true
  }
}

#if DEBUG
  import SwiftUI

  // The Weekend Getaway fixture's first four items cover every row state: unchecked, unchecked with
  // notes, checked, checked with notes. The last row is the blank scratch row the add button leaves.
  #Preview("Row states") {
    let items = Array(PreviewSupport.checklist(id: SampleData.weekendGetawayId).items.prefix(4)) + [Item()]
    let stack = UIStackView(arrangedSubviews: items.map { item in
      let row = ItemContentView()
      row.item = item
      return row
    })
    stack.axis = .vertical
    stack.translatesAutoresizingMaskIntoConstraints = false

    let viewController = UIViewController()
    viewController.view.backgroundColor = .systemBackground
    viewController.view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.topAnchor),
      stack.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
    ])
    return viewController
  }
#endif
