//
//  InfoRowTableViewCell.swift
//  checklists
//
//  Created by Jimmy Ho on 11/19/20.
//  Copyright © 2020 Jimmy Ho. All rights reserved.
//

import UIKit

class InfoRowTableViewCell: UITableViewCell {
  let iconImageView = UIImageView()
  let nameLabel = UILabel()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    commonSetup()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError()
  }

  private func commonSetup() {
    iconImageView.contentMode = .scaleAspectFit
    iconImageView.tintColor = Colors.teal

    nameLabel.font = .systemFont(ofSize: 18.0)
    nameLabel.numberOfLines = 2

    contentView.addSubview(iconImageView)
    contentView.addSubview(nameLabel)
    iconImageView.translatesAutoresizingMaskIntoConstraints = false
    nameLabel.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      iconImageView.widthAnchor.constraint(equalToConstant: 24.0),
      iconImageView.heightAnchor.constraint(equalToConstant: 24.0),
      iconImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
      iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

      nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8.0),
      nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16.0),
      nameLabel.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
    ])
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    iconImageView.image = nil
    nameLabel.text = nil
  }
}
