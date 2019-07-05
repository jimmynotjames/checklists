//
//  ItemContentView.swift
//  checklists
//
//  Created by Jimmy Ho on 5/19/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

protocol ItemContentViewDelegate: class {
  func itemContentViewCheckboxButtonTapped(_ itemContentView: ItemContentView)
  func itemContentView(_ itemContentView: ItemContentView, nameFieldUpdatedWith name: String)
  func itemContentView(_ itemContentView: ItemContentView, notesFieldUpdatedWith notes: String)
}

class ItemContentView: UIView {
  private lazy var checkboxButton: CheckboxButton = {
    let button = CheckboxButton()
    button.addTarget(self, action: #selector(checkboxButtonTapped(sender:)), for: .touchUpInside)
    return button
  }()
  private lazy var nameField: UITextField = {
    let textField = UITextField()
    textField.delegate = self
    return textField
  }()
  private lazy var notesTextView: UITextView = {
    let textView = UITextView()
    textView.delegate = self
    return textView
  }()
  private let containerView = UIView()

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

  private func installConstraints() {
    let views = [ "checkboxButton": checkboxButton,
                  "containerView": containerView,
                  "nameField": nameField,
                  "notesTextView": notesTextView ]
    views.forEach({ $0.value.translatesAutoresizingMaskIntoConstraints = false })

    NSLayoutConstraint.activate(
      [NSLayoutConstraint.constraints(withVisualFormat: "H:|-4-[checkboxButton]-(-4)-[containerView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "V:|[checkboxButton]", options: [], metrics: nil, views: views),

       NSLayoutConstraint.constraints(withVisualFormat: "V:|-10-[containerView]-8-|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "V:|[nameField]-(-4)-[notesTextView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|[nameField]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|-(-4)-[notesTextView]|", options: [], metrics: nil, views: views),
        ].flatMap({ $0 }))
    notesTextView.heightAnchor.constraint(equalToConstant: 50.0).isActive = true // TODO: Add this to array.
  }

  @objc func checkboxButtonTapped(sender: UIButton) {
    delegate?.itemContentViewCheckboxButtonTapped(self)
  }
}

extension ItemContentView: UITextFieldDelegate {
  func textFieldDidEndEditing(_ textField: UITextField) {
    delegate?.itemContentView(self, nameFieldUpdatedWith: textField.text ?? "")
  }
}

extension ItemContentView: UITextViewDelegate {
  func textViewDidEndEditing(_ textView: UITextView) {
    delegate?.itemContentView(self, notesFieldUpdatedWith: textView.text)
  }
}
