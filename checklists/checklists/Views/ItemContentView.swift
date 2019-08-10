//
//  ItemContentView.swift
//  checklists
//
//  Created by Jimmy Ho on 5/19/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

private var minNameFieldHeight: CGFloat = 24.0
private var minNotesTextViewHeight: CGFloat = 32.0

protocol ItemContentViewDelegate: class {
  func itemContentViewCheckboxButtonTapped(_ itemContentView: ItemContentView)
  func itemContentViewNameFieldDidBeginEditing(_ itemContentView: ItemContentView)
  func itemContentViewDidFinishEditing(_ itemContentView: ItemContentView)
  func itemContentViewHeightUpdated(_ itemContentView: ItemContentView)
  func itemContentView(_ itemContentView: ItemContentView, nameFieldUpdatedWith name: String)
  func itemContentView(_ itemContentView: ItemContentView, notesFieldUpdatedWith notes: String)
}

class ItemContentView: UIView {
  var item: Item? {
    didSet {
      if let item = item {
        checkboxButton.setCheckboxState(with: item.status)
        nameTextView.text = item.name
        if let notes = item.notes {
          notesTextView.text = notes
        }
        let textColor = item.status == .checked ? Colors.inactiveText : .black
        nameTextView.textColor = textColor
        notesTextView.textColor = textColor
      } else {
        checkboxButton.setCheckboxState(with: .unchecked)
        nameTextView.text = ""
        notesTextView.text = ""
      }
    }
  }

  weak var delegate: ItemContentViewDelegate?

  var addAnotherButtonTappedAction: (() -> Void)? {
    didSet {
      nameTextView.addAnotherButtonTappedAction = addAnotherButtonTappedAction
      notesTextView.addAnotherButtonTappedAction = addAnotherButtonTappedAction
    }
  }

  private lazy var checkboxButton: CheckboxButton = {
    let button = CheckboxButton()
    button.addTarget(self, action: #selector(checkboxButtonTapped(sender:)), for: .touchUpInside)
    return button
  }()
  private lazy var nameTextView: CLTextView = {
    let textView = CLTextView()
    textView.delegate = self
    textView.font = UIFont.systemFont(ofSize: 20.0, weight: .regular)
    textView.returnKeyType = .done
    return textView
  }()
  private lazy var notesTextView: CLTextView = {
    let textView = CLTextView()
    textView.placeholderText = "Notes"
    textView.font = UIFont.systemFont(ofSize: 14.0)
    textView.delegate = self
    return textView
  }()
  private let containerView = UIView()

  private lazy var notesTextViewHeightConstraint: NSLayoutConstraint = {
    return notesTextView.heightAnchor.constraint(equalToConstant: 0.0)
  }()

  private var wasInputFieldTapped: Bool = false

  convenience init() {
    self.init(frame: .zero)
  }

  override init(frame: CGRect) {
    super.init(frame: frame)

    addSubview(checkboxButton)
    addSubview(containerView)
    containerView.addSubview(notesTextView)
    containerView.addSubview(nameTextView)

    installConstraints()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("This init() not supported.")
  }

  func setDelegate(_ delegate: ItemContentViewDelegate) {
    self.delegate =  delegate
  }

  func updateTextViewHeight(isExpanded: Bool) {
    notesTextViewHeightConstraint.isActive = false
    if isExpanded {
      notesTextViewHeightConstraint = notesTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: minNotesTextViewHeight)
    } else {
      notesTextViewHeightConstraint = notesTextView.heightAnchor.constraint(equalToConstant: 0.0)
    }
    notesTextViewHeightConstraint.isActive = true
  }

  func startEditing() {
    _ = nameTextView.becomeFirstResponder()
  }

  /*
   I need to detect when to collapse the view (if notes are empty), but if user taps from one input
   field to another, I can't tell properly with just endEditing...().
   */
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let view = super.hitTest(point, with: event)
    wasInputFieldTapped = view != nil && (view! == nameTextView || view! == notesTextView)
    return view
  }

  private func installConstraints() {
    let views = [ "itemContentView": self, // No actual effect, except to suppress intermediate unsatisfiable constraint warnings.
                  "checkboxButton": checkboxButton,
                  "containerView": containerView,
                  "nameTextView": nameTextView,
                  "notesTextView": notesTextView ]
    views.forEach({ $0.value.translatesAutoresizingMaskIntoConstraints = false })

    nameTextView.setContentCompressionResistancePriority(.required, for: .vertical)
    nameTextView.setContentHuggingPriority(.required, for: .vertical)

    NSLayoutConstraint.activate(
      [NSLayoutConstraint.constraints(withVisualFormat: "H:|-4-[checkboxButton]-(-4)-[containerView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "V:|[checkboxButton]", options: [], metrics: nil, views: views),

       NSLayoutConstraint.constraints(withVisualFormat: "V:|-8-[containerView]-8-|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "V:|[nameTextView]-(4)-[notesTextView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|[nameTextView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|[notesTextView]|", options: [], metrics: nil, views: views),
       [nameTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: minNameFieldHeight), notesTextViewHeightConstraint]
        ].flatMap({ $0 }))
  }

  @objc func checkboxButtonTapped(sender: UIButton) {
    delegate?.itemContentViewCheckboxButtonTapped(self)
  }

  private func finishEditingViewIfNecessary() {
    if !wasInputFieldTapped {
      delegate?.itemContentViewDidFinishEditing(self)
    }
  }
}

extension ItemContentView: UITextFieldDelegate {
  func textFieldDidBeginEditing(_ textField: UITextField) {
    delegate?.itemContentViewNameFieldDidBeginEditing(self)
    wasInputFieldTapped = false
  }
  func textFieldDidEndEditing(_ textField: UITextField) {
    delegate?.itemContentView(self, nameFieldUpdatedWith: textField.text ?? "")
    finishEditingViewIfNecessary()
  }
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return false
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
    delegate?.itemContentViewHeightUpdated(self)
  }
  func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    if text == "\n" && textView == nameTextView {
      textView.resignFirstResponder()
      return false
    }
    return true
  }
}
