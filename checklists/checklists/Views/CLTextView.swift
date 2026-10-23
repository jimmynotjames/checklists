//
//  CLTextView.swift
//  checklists
//
//  Created by Jimmy Ho on 7/31/19.
//

/*
 Two major features here:
 - Adjusted UITextView so that it grows/shrinks height as user is typing.
 - Added placeholder text.

 To use, set a >= minimum height constraint and it will show with a minimum height and grow as it expands beyond that.
 */

import UIKit

protocol CLTextViewDelegate: UITextViewDelegate {
  func textViewDidUpdateHeight(_ textView: CLTextView)
}

class CLTextView: UITextView {
  @objc var placeholderText: String? { // @objc to allow setting in InterfaceBuilder
    didSet {
      placeholderLabel.text = placeholderText
      updatePlaceholderLabel()
    }
  }

  var placeholderTextColor: UIColor = Colors.placeholderText {
    didSet {
      placeholderLabel.textColor = placeholderTextColor
    }
  }

  override var text: String! {
    get {
      super.text
    }
    set {
      super.text = newValue
      updatePlaceholderLabel()
    }
  }

  override var font: UIFont? {
    get {
      super.font
    }
    set {
      super.font = newValue
      placeholderLabel.font = font ?? UIFont.systemFont(ofSize: 8.0)
    }
  }

  private lazy var placeholderLabel: UILabel = {
    let label = UILabel()
    label.textColor = placeholderTextColor
    label.backgroundColor = .clear
    label.isUserInteractionEnabled = false
    // The text view's own label already names the field; exposed, the placeholder is a separate,
    // tiny element of its own.
    label.isAccessibilityElement = false
    // Follows a text-size change on its own: UIKit rescales the text view's font without going
    // through the `font` setter above, so the mirroring there would miss it.
    label.adjustsFontForContentSizeCategory = true
    return label
  }()

  init() {
    super.init(frame: .zero, textContainer: nil)
    commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    isScrollEnabled = false
    // Without this the placeholder label, sized by the scroll view's contentSize rather than its frame, spills out of a collapsed field.
    clipsToBounds = true
    textContainer.heightTracksTextView = true

    textContainerInset = .zero
    textContainer.lineFragmentPadding = 0.0

    backgroundColor = .clear

    setUpSubviews()

    updatePlaceholderLabel()

    textDropDelegate = self

    NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: UITextView.textDidChangeNotification, object: self)
  }

  private func setUpSubviews() {
    addSubview(placeholderLabel)

    let views = ["placeholderLabel": placeholderLabel]
    views.forEach { $0.value.translatesAutoresizingMaskIntoConstraints = false }

    NSLayoutConstraint.activate(
      NSLayoutConstraint.constraints(withVisualFormat: "H:|[placeholderLabel]|", options: [], metrics: nil, views: views)
        + [placeholderTopConstraint, placeholderBottomConstraint],
    )
  }

  // The placeholder sits on the first line of text, so it follows the text inset's top and bottom.
  // Sides stay pinned: no caller insets them.
  private lazy var placeholderTopConstraint = placeholderLabel.topAnchor.constraint(equalTo: topAnchor)
  private lazy var placeholderBottomConstraint = placeholderLabel.bottomAnchor.constraint(equalTo: bottomAnchor)

  override var textContainerInset: UIEdgeInsets {
    didSet {
      placeholderTopConstraint.constant = textContainerInset.top
      placeholderBottomConstraint.constant = -textContainerInset.bottom
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc func textDidChange(notification: Notification) {
    if let textView = notification.object as? CLTextView, textView == self {
      updatePlaceholderLabel()
    }
  }

  private func updatePlaceholderLabel() {
    if hasText == false, placeholderText != nil, !placeholderText!.isEmpty {
      placeholderLabel.isHidden = false
    } else {
      placeholderLabel.isHidden = true
    }
  }
}

/// Need this because the reordering of rows using Drag/Drop is causing it to accidentally drop into the textView instead of inserting in between rows.
extension CLTextView: UITextDropDelegate {
  /// TECH DEBT: This may have long-term consequences in iPad and Mac App, if we move there. Maybe people will want to drop text in there??
  func textDroppableView(_: UIView & UITextDroppable, proposalForDrop _: UITextDropRequest) -> UITextDropProposal {
    UITextDropProposal(operation: .forbidden)
  }
}
