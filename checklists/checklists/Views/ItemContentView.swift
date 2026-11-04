//
//  ItemContentView.swift
//  checklists
//
//  Created by Jimmy Ho on 5/19/19.
//

import UIKit

/// Apple's minimum touch target, for both fields, so a tap just above or below the text still lands
/// on the field.
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
  private static let nameTextStyle: UIFont.TextStyle = .title2
  /// The name field's top inset: the row's top margin, inside the field.
  private static let nameTopInset: CGFloat = 10.0

  var item: Item? {
    didSet {
      if let item {
        nameTextView.text = item.name
        checkboxButton.setItemName(item.name)
        if let notes = item.notes {
          notesTextView.text = notes
        } else {
          notesTextView.text = ""
        }
        updateCheckedStatus()
        refreshHeight()
      } else {
        checkboxButton.setCheckboxState(with: .unchecked)
        checkboxButton.setItemName(nil)
        nameTextView.text = ""
        notesTextView.text = ""
      }
    }
  }

  weak var delegate: ItemContentViewDelegate?

  var isEditing: Bool {
    nameTextView.isFirstResponder || notesTextView.isFirstResponder
  }

  /// The caret of whichever field is being typed into, in this view's coordinates. Nil when neither
  /// is.
  var editingCaretRect: CGRect? {
    guard
      let field = [nameTextView, notesTextView].first(where: \.isFirstResponder),
      let caret = field.selectedTextRange?.end
    else { return nil }
    return convert(field.caretRect(for: caret), from: field)
  }

  private(set) lazy var checkboxButton: CheckboxButton = {
    let button = CheckboxButton()
    button.addTarget(self, action: #selector(checkboxButtonTapped(sender:)), for: .touchUpInside)
    return button
  }()

  private lazy var nameTextView: CLTextView = {
    let textView = CLTextView()
    textView.delegate = self
    textView.font = .preferredFont(forTextStyle: Self.nameTextStyle)
    textView.adjustsFontForContentSizeCategory = true
    // The row's top margin and the gap down to the notes, inside the field rather than around it.
    textView.textContainerInset = UIEdgeInsets(top: Self.nameTopInset, left: 0.0, bottom: 8.0, right: 0.0)
    textView.returnKeyType = .next
    textView.accessibilityIdentifier = "itemNameTextView"
    textView.accessibilityLabel = String(
      localized: "item.name.accessibilityLabel",
      defaultValue: "checklist item: ",
      comment: "VoiceOver label read before an item's name in the editable item row. Keep the trailing space and colon.",
    )
    return textView
  }()

  private lazy var notesTextView: CLTextView = {
    let textView = CLTextView()
    textView.placeholderText = CommonStrings.notesPlaceholder
    textView.font = .preferredFont(forTextStyle: .subheadline)
    textView.adjustsFontForContentSizeCategory = true
    // The row's bottom margin, inside the field rather than below it; see `containerBottomConstraint`.
    textView.textContainerInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 4.0, right: 0.0)
    textView.returnKeyType = .default
    textView.delegate = self
    textView.accessibilityIdentifier = "itemNotesTextView"
    textView.accessibilityLabel = String(
      localized: "item.notes.accessibilityLabel",
      defaultValue: "optional notes: ",
      comment: "VoiceOver label read before an item's notes in the editable item row. Keep the trailing space and colon.",
    )
    return textView
  }()

  private let containerView = UIView()

  private lazy var notesTextViewHeightConstraint: NSLayoutConstraint = notesTextView.heightAnchor.constraint(equalToConstant: 0.0)
  /// The row's bottom margin while the notes field is hidden. A shown notes field takes it as its
  /// bottom inset instead, so it stays tappable.
  ///
  /// Below required, so a checkbox taller than the text it sits beside can push the row down past it.
  private lazy var containerBottomConstraint: NSLayoutConstraint = {
    let constraint = bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: notesTextView.textContainerInset.bottom)
    constraint.priority = .defaultHigh
    return constraint
  }()

  /// Holds the checkbox on the centre line of the name's first line, which moves with the text size.
  /// Below required, so at small sizes, where that centre sits closer to the top than half the
  /// checkbox, the checkbox stops at the row's top edge instead.
  private lazy var checkboxCenterConstraint: NSLayoutConstraint = {
    let constraint = checkboxButton.centerYAnchor.constraint(equalTo: nameTextView.topAnchor, constant: nameFirstLineCenterY)
    constraint.priority = UILayoutPriority(999.0)
    return constraint
  }()

  private var nameFirstLineCenterY: CGFloat {
    Self.nameTopInset + UIFont.preferredFont(forTextStyle: Self.nameTextStyle, compatibleWith: traitCollection).lineHeight / 2.0
  }

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

    // The fonts rescale themselves; the checkbox's line-up has to be told.
    registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: Self, _) in
      view.checkboxCenterConstraint.constant = view.nameFirstLineCenterY
    }
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

    // Never while it has the keyboard: a row collapses mid-edit when Add item is tapped, and
    // dropping the focused field would strand VoiceOver. It goes once editing ends and the row
    // collapses again.
    let hidesNotes = !isExpanded && !notesTextView.isFirstResponder
    guard isNotesHiddenFromAccessibility != hidesNotes else { return }
    isNotesHiddenFromAccessibility = hidesNotes
    // Only for a row on screen: one being configured while the table scrolls is read as it appears.
    guard window != nil else { return }
    UIAccessibility.post(notification: .layoutChanged, argument: nil)
  }

  /// A collapsed notes field is zero-height, so VoiceOver would otherwise stop on an invisible field
  /// in every row without notes. It returns with the field, once the name is being edited.
  private var isNotesHiddenFromAccessibility = false

  /// Listed, because un-hiding a field with `accessibilityElementsHidden` doesn't reach the
  /// accessibility tree inside a table cell. Leading to trailing, as VoiceOver reads the row by
  /// position: the checkbox sits at the leading edge.
  override var accessibilityElements: [Any]? {
    get { isNotesHiddenFromAccessibility ? [checkboxButton, nameTextView] : [checkboxButton, nameTextView, notesTextView] }
    // Derived from the notes field's state; nothing sets it.
    set { _ = newValue }
  }

  func startEditing() {
    _ = nameTextView.becomeFirstResponder()
  }

  /// Reorder Items mode: the row shows as usual but takes no touches, and its text cannot be
  /// edited. `isEditable` and `isEnabled` as well, because a VoiceOver double-tap does not go
  /// through hit-testing; disabling the checkbox also has VoiceOver read it as dimmed.
  func setReordering(_ reordering: Bool) {
    isUserInteractionEnabled = !reordering
    checkboxButton.isEnabled = !reordering
    nameTextView.isEditable = !reordering
    notesTextView.isEditable = !reordering
  }

  /// Put on every element VoiceOver can land on in the row: the row itself is not one, and custom
  /// actions are not inherited from a container.
  func setAccessibilityActions(_ actions: [UIAccessibilityCustomAction]) {
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
       [checkboxCenterConstraint,
        checkboxButton.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
        bottomAnchor.constraint(greaterThanOrEqualTo: checkboxButton.bottomAnchor)],

       [containerView.topAnchor.constraint(equalTo: topAnchor), containerBottomConstraint],
       NSLayoutConstraint.constraints(withVisualFormat: "V:|[nameTextView][notesTextView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|[nameTextView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|[notesTextView]|", options: [], metrics: nil, views: views),
       [nameTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: minNameFieldHeight), notesTextViewHeightConstraint]].flatMap(\.self),
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

  func textViewDidChange(_ textView: UITextView) {
    if textView == nameTextView {
      checkboxButton.setItemName(textView.text)
    }
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
  // notes, checked, checked with notes. Then a long name over a long note, to wrap both at large text
  // sizes, and last the blank scratch row the add button leaves. Scrolls, so every row stays
  // reachable at the accessibility sizes.
  #Preview("Row states") {
    let fixtureItems = Array(PreviewSupport.checklist(id: SampleData.weekendGetawayId).items.prefix(4))
    let longItem = Item(name: fixtureItems[2].name, notes: fixtureItems[1].notes)
    let items = fixtureItems + [longItem, Item()]
    let stack = UIStackView(arrangedSubviews: items.map { item in
      let row = ItemContentView()
      row.item = item
      return row
    })
    stack.axis = .vertical
    stack.translatesAutoresizingMaskIntoConstraints = false

    let scrollView = UIScrollView()
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(stack)

    let viewController = UIViewController()
    viewController.view.backgroundColor = Colors.defaultBackground
    viewController.view.addSubview(scrollView)
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor),
      scrollView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
      stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
      stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
      stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
    ])
    return viewController
  }
#endif
