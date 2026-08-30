//
//  MainMenuItemTableViewCell.swift
//  checklists
//
//  Created by Jimmy Ho on 8/30/26.
//

import UIKit

class MainMenuItemTableViewCell: UITableViewCell {
  let iconImageView = UIImageView()
  let titleLabel = UILabel()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    commonSetup()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError()
  }

  private func commonSetup() {
    backgroundColor = .clear

    iconImageView.contentMode = .scaleAspectFit

    titleLabel.font = .systemFont(ofSize: 22.0, weight: .medium)
    titleLabel.textColor = Colors.defaultBackground

    contentView.addSubview(iconImageView)
    contentView.addSubview(titleLabel)
    iconImageView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      iconImageView.widthAnchor.constraint(equalToConstant: 44.0),
      iconImageView.heightAnchor.constraint(equalToConstant: 44.0),
      iconImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
      iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

      titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8.0),
      titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20.0),
      titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
    ])
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    iconImageView.image = nil
    titleLabel.text = nil
  }
}
