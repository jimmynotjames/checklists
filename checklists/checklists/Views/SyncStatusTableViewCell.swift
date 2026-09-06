//
//  SyncStatusTableViewCell.swift
//  checklists
//

import UIKit

/// Subtitle-style row for the Settings iCloud section: a title plus a status line below it.
/// Display-only — there is nothing to tap, so selection is disabled.
class SyncStatusTableViewCell: UITableViewCell {
  let nameLabel = UILabel()
  let detailLabel = UILabel()

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
    selectionStyle = .none

    // Scaled rather than a plain `systemFont(ofSize:)`: `adjustsFontForContentSizeCategory` does
    // nothing unless the font came from `UIFontMetrics` or `preferredFont(forTextStyle:)`, so the
    // flag alone would claim Dynamic Type support this label does not have. 18pt matches the
    // neighbouring rows at the default content size.
    nameLabel.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 18.0))
    nameLabel.numberOfLines = 0
    nameLabel.adjustsFontForContentSizeCategory = true

    detailLabel.font = .preferredFont(forTextStyle: .footnote)
    detailLabel.textColor = Colors.inactiveText
    detailLabel.numberOfLines = 0
    detailLabel.adjustsFontForContentSizeCategory = true

    contentView.addSubview(nameLabel)
    contentView.addSubview(detailLabel)
    installConstraints()
  }

  private func installConstraints() {
    nameLabel.translatesAutoresizingMaskIntoConstraints = false
    detailLabel.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10.0),
      nameLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
      nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16.0),

      detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2.0),
      detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
      detailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 10.0),
    ])
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    nameLabel.text = nil
    detailLabel.text = nil
  }
}
