//
//  ItemTableViewCell.swift
//  checklists
//
//  Created by Jimmy Ho on 5/11/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

class ItemTableViewCell: UITableViewCell {
  private let itemCellViewController = ItemCellViewController()
  private lazy var itemContentView: ItemContentView = {
    return itemCellViewController.view as! ItemContentView
  }()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    itemContentView.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(itemContentView)

    [contentView.topAnchor.constraint(equalTo: itemContentView.topAnchor),
     contentView.bottomAnchor.constraint(equalTo: itemContentView.bottomAnchor),
     contentView.leftAnchor.constraint(equalTo: itemContentView.leftAnchor),
     contentView.rightAnchor.constraint(equalTo: itemContentView.rightAnchor)
    ].forEach { $0.isActive = true  }
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("This init() not supported.")
  }

  // TODO: Delete this template code?
  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
  }

  func setContentView(with item: Item) {
    itemCellViewController.item = item
  }
}
