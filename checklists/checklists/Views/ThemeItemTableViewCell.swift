//
//  ThemeItemTableViewCell.swift
//  checklists
//
//  Created by Jimmy Ho on 11/19/20.
//  Copyright © 2020 Jimmy Ho. All rights reserved.
//

import UIKit

class ThemeItemTableViewCell: UITableViewCell {
  let nameLabel = UILabel()
  let checkboxButton = RoundCheckboxButton()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    commonSetup()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError()
  }

  private func commonSetup() {
    tintColor = Colors.teal
    nameLabel.font = .systemFont(ofSize: 18.0)

    contentView.addSubview(nameLabel)
    contentView.addSubview(checkboxButton)
    nameLabel.translatesAutoresizingMaskIntoConstraints = false
    checkboxButton.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      checkboxButton.widthAnchor.constraint(equalToConstant: 44.0),
      checkboxButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2.0),
      checkboxButton.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),

      nameLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
      nameLabel.trailingAnchor.constraint(equalTo: checkboxButton.leadingAnchor, constant: -8.0),
      nameLabel.centerYAnchor.constraint(equalTo: checkboxButton.centerYAnchor),
    ])
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    nameLabel.text = nil
    checkboxButton.isSelected = false
  }
}
