//
//  ItemContentView.swift
//  checklists
//
//  Created by Jimmy Ho on 5/19/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

struct ItemContentViewModel {
  
}

class ItemContentView: UIView {
  private let checkboxButton = CheckboxButton()
  private let nameField = UITextField()
  private let notesField = UITextView()
  private let containerView = UIView()

  convenience init() {
    self.init(frame: .zero)
  }

  override init(frame: CGRect) {
    super.init(frame: frame)

    addSubview(checkboxButton)
    containerView.addSubview(nameField)
    containerView.addSubview(notesField)

    installConstraints()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("This init() not supported.")
  }

  private func installConstraints() {
    let views = [ "checkboxButton": checkboxButton,
                  "containerView": containerView,
                  "nameField": nameField,
                  "notesField": notesField ]
    views.forEach({ $0.value.translatesAutoresizingMaskIntoConstraints = false })

    NSLayoutConstraint.activate(
      [NSLayoutConstraint.constraints(withVisualFormat: "H:|[checkboxButton]-[containerView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "V:|[checkboxButton]", options: [], metrics: nil, views: views),

       NSLayoutConstraint.constraints(withVisualFormat: "V:|[containerView]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "V:|[nameField]-[notesField]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|[nameField]|", options: [], metrics: nil, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|[notesField]|", options: [], metrics: nil, views: views),
        ].flatMap({ $0 }))
  }
}
