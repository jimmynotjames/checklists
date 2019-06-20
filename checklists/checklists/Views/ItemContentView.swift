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
}

class ItemContentView: UIView {
  private let checkboxButton: CheckboxButton = {
    let button = CheckboxButton()
    button.addTarget(self, action: #selector(checkboxButtonTapped(sender:)), for: .touchUpInside)
    return button
  }()
  lazy private var nameField: UITextField = {
    let textField = UITextField()
    textField.delegate = self
    return textField
  }()
  private let notesTextView = UITextView()
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
    containerView.addSubview(nameField)
    containerView.addSubview(notesTextView)

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
      [NSLayoutConstraint.constraints(withVisualFormat: "H:|[checkboxButton]-[containerView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "V:|[checkboxButton]", options: [], metrics: nil, views: views),

       NSLayoutConstraint.constraints(withVisualFormat: "V:|[containerView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "V:|[nameField]-[notesTextView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|[nameField]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|[notesTextView]|", options: [], metrics: nil, views: views),
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
