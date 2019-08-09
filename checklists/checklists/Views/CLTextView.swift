//
//  CLTextView.swift
//  checklists
//
//  Created by Jimmy Ho on 7/31/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

protocol CLTextViewDelegate: UITextViewDelegate {
  func textViewDidUpdateHeight(_ textView: CLTextView)
}

class CLTextView: UITextView {

  var placeholderText: String? {
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
