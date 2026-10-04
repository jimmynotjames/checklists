//
//  ItemTableViewCell.swift
//  checklists
//
//  Created by Jimmy Ho on 5/11/19.
//

import UIKit

class ItemTableViewCell: UITableViewCell {
  var itemContentView: ItemContentView = .init(frame: .zero)

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    backgroundColor = .clear
    installConstraints()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    fatalError() // Not in use.
  }

  private func installConstraints() {
    contentView.addSubview(itemContentView)
    itemContentView.translatesAutoresizingMaskIntoConstraints = false

    let column = contentView.addReadableColumnGuide()
    [contentView.topAnchor.constraint(equalTo: itemContentView.topAnchor),
     contentView.bottomAnchor.constraint(equalTo: itemContentView.bottomAnchor),
     column.leadingAnchor.constraint(equalTo: itemContentView.leadingAnchor),
     column.trailingAnchor.constraint(equalTo: itemContentView.trailingAnchor)].forEach { $0.isActive = true }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    itemContentView.item = nil
  }
}
