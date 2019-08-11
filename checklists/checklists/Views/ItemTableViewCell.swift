//
//  ItemTableViewCell.swift
//  checklists
//
//  Created by Jimmy Ho on 5/11/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

class ItemTableViewCell: UITableViewCell {
  var itemContentView: ItemContentView = ItemContentView(frame: .zero) // Exposing this because I'm tired of delegate chains.

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

    [contentView.topAnchor.constraint(equalTo: itemContentView.topAnchor),
     contentView.bottomAnchor.constraint(equalTo: itemContentView.bottomAnchor),
     contentView.leftAnchor.constraint(equalTo: itemContentView.leftAnchor),
     contentView.rightAnchor.constraint(equalTo: itemContentView.rightAnchor)
      ].forEach { $0.isActive = true  }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    itemContentView.item = nil
  }
}
