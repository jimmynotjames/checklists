//
//  ItemContentView.swift
//  checklists
//
//  Created by Jimmy Ho on 5/19/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit
import GrowingTextView

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
        nameField.text = item.name
        if let notes = item.notes {
          notesTextView.text = notes
        }
      } else {
        checkboxButton.setCheckboxState(with: .unchecked)
        nameField.text = nil
        notesTextView.text = ""
      }
    }
  }

  weak var delegate: ItemContentViewDelegate?

  private lazy var checkboxButton: CheckboxButton = {
    let button = CheckboxButton()
    button.addTarget(self, action: #selector(checkboxButtonTapped(sender:)), for: .touchUpInside)
    return button
  }()
  private lazy var nameField: UITextField = {
    let textField = UITextField()
    textField.delegate = self
    textField.font = UIFont.systemFont(ofSize: 20.0, weight: .regular)
    textField.returnKeyType = .done
    return textField
  }()
  private lazy var notesTextView: GrowingTextView = {
    let textView = GrowingTextView()
    textView.delegate = self
    textView.font = UIFont.systemFont(ofSize: 14.0)
    textView.textContainer.heightTracksTextView = true
    textView.alwaysBounceVertical = false
    textView.placeholder = "Notes"
    textView.placeholderColor = .lightGray
    return textView
  }()
  private let containerView = UIView()

  private var wasInputFieldTapped: Bool = false

  convenience init() {
    self.init(frame: .zero)
  }

  override init(frame: CGRect) {
    super.init(frame: frame)

    addSubview(checkboxButton)
    addSubview(containerView)
    containerView.addSubview(notesTextView)
    containerView.addSubview(nameField) // Name field needs to be in front due to overlapping textView

    installConstraints()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("This init() not supported.")
  }

  func setDelegate(_ delegate: ItemContentViewDelegate) {
    self.delegate =  delegate
  }

  func updateTextViewHeight(isExpanded: Bool) {
    notesTextView.maxHeight = isExpanded ? 32.0 : 0.0
    notesTextView.maxHeight = isExpanded ? 160.0 : 0.01  // zero means it's infinite.
  }

  /*
   I need to detect when to collapse the view (if notes are empty), but if user taps from one input
   field to another, I can't tell properly with just endEditing...().
   */
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let view = super.hitTest(point, with: event)
    wasInputFieldTapped = view != nil && (view! == nameField || view! == notesTextView)
    return view
  }

  private func installConstraints() {
    let views = [ "itemContentView": self, // No actual effect, except to suppress intermediate unsatisfiable constraint warnings.
                  "checkboxButton": checkboxButton,
                  "containerView": containerView,
                  "nameField": nameField,
                  "notesTextView": notesTextView ]
    views.forEach({ $0.value.translatesAutoresizingMaskIntoConstraints = false })

    NSLayoutConstraint.activate(
      [NSLayoutConstraint.constraints(withVisualFormat: "H:|-4-[checkboxButton]-(-4)-[containerView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "V:|[checkboxButton]", options: [], metrics: nil, views: views),

       NSLayoutConstraint.constraints(withVisualFormat: "V:|-8-[containerView]-8-|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "V:|[nameField]-(-4)-[notesTextView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|[nameField]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|-(-4)-[notesTextView]|", options: [], metrics: nil, views: views),
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
    wasInputFieldTapped = false
  }
  func textViewDidEndEditing(_ textView: UITextView) {
    delegate?.itemContentView(self, notesFieldUpdatedWith: textView.text)
    finishEditingViewIfNecessary()
  }
}

extension ItemContentView: GrowingTextViewDelegate {
  func textViewDidChangeHeight(_ textView: GrowingTextView, height: CGFloat) {
    delegate?.itemContentViewHeightUpdated(self)
  }
}
