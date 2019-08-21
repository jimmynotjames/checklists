//
//  CLTextView.swift
//  checklists
//
//  Created by Jimmy Ho on 7/31/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
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

  var inputAccessoryButtonName: String = "Dismiss"
  var inputAccessoryButtonTappedAction: (() -> Void)? {
    didSet {
      if inputAccessoryButtonTappedAction != nil {
        inputAccessoryView = inputAccessoryToolbar
      } else {
        inputAccessoryView = nil
      }
    }
  }
  @objc func inputAccessoryButtonTapped() {
    inputAccessoryButtonTappedAction?()
  }

  @objc var placeholderText: String? { // @objc to allow setting in InterfaceBuilder
    didSet {
      placeholderLabel.text = placeholderText
      updatePlaceholderLabel()
    }
  }
  var placeholderTextColor: UIColor = .lightGray {
    didSet {
      placeholderLabel.textColor = placeholderTextColor
    }
  }

  override var text: String! {
    get {
      return super.text
    }
    set {
      super.text = newValue
      updatePlaceholderLabel()
    }
  }

  override var font: UIFont? {
    get {
      return super.font
    }
    set {
      super.font = newValue
      placeholderLabel.font = font ?? UIFont.systemFont(ofSize: 8.0)
    }
  }

  private lazy var inputAccessoryToolbar: UIToolbar = {
    let toolbar = UIToolbar()
    let button = UIBarButtonItem(title: inputAccessoryButtonName, style: .plain, target: self, action: #selector(inputAccessoryButtonTapped))
    button.tintColor = Colors.teal
    let buttons = [
      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
      button,
    ]
    toolbar.setItems(buttons, animated: false)
    toolbar.sizeToFit()
    return toolbar
  }()

  private lazy var placeholderLabel: UILabel = {
    let label = UILabel()
    label.textColor = placeholderTextColor
    label.backgroundColor = .clear
    label.isUserInteractionEnabled = false
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

    let views = [ "placeholderLabel": placeholderLabel ]
    views.forEach({ $0.value.translatesAutoresizingMaskIntoConstraints = false })

    NSLayoutConstraint.activate(
      [NSLayoutConstraint.constraints(withVisualFormat: "H:|[placeholderLabel]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "V:|[placeholderLabel]|", options: [], metrics: nil, views: views),
        ].flatMap({ $0 }))
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
    if hasText == false && placeholderText != nil && placeholderText!.count > 0 {
      placeholderLabel.isHidden = false
    } else {
      placeholderLabel.isHidden = true
    }
  }
}

// Need this because the reordering of rows using Drag/Drop is causing it to accidentally drop into the textView instead of inserting in between rows.
extension CLTextView: UITextDropDelegate {
  // TODO: This may have long-term consequences in iPad and Mac App, if we move there. Maybe people will want to drop text in there??
  func textDroppableView(_ textDroppableView: UIView & UITextDroppable, proposalForDrop drop: UITextDropRequest) -> UITextDropProposal {
    return UITextDropProposal(operation: .cancel)
  }
}
