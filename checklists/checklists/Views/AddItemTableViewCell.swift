//
//  AddItemTableViewCell.swift
//  checklists
//
//  Created by Jimmy Ho on 7/25/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

protocol AddItemTableViewCellDelegate: class {
  func addItemTableViewCellTapped()
}

class AddItemTableViewCell: UITableViewCell {
  weak var delegate: AddItemTableViewCellDelegate?

  let addButton: CLButton = {
    let button = CLButton(frame: .zero)
    button.setTitle("Add", for: .normal)
    return button
  }()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)


    addButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

    contentView.addSubview(addButton)

    addButton.translatesAutoresizingMaskIntoConstraints = false

    [contentView.topAnchor.constraint(equalTo: addButton.topAnchor, constant: -16.0),
     contentView.bottomAnchor.constraint(equalTo: addButton.bottomAnchor),
     contentView.leftAnchor.constraint(equalTo: addButton.leftAnchor, constant: -8.0),
     contentView.rightAnchor.constraint(equalTo: addButton.rightAnchor, constant: 8.0),
     contentView.heightAnchor.constraint(equalToConstant: 60.0)
      ].forEach { $0.isActive = true  }
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }

  @objc func buttonTapped() {
    delegate?.addItemTableViewCellTapped()
  }
}
