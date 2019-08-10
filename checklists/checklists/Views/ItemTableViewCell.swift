//
//  ItemTableViewCell.swift
//  checklists
//
//  Created by Jimmy Ho on 5/11/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

class ItemTableViewCell: UITableViewCell {
  var itemCellViewController: ItemCellViewController?
  var itemContentView: ItemContentView?

  override func prepareForReuse() {
    if let itemContentView = itemContentView, itemContentView.superview == contentView {
      itemContentView.removeFromSuperview()
    }
    itemContentView = nil
  }

  func setViewController(with itemCellViewController: ItemCellViewController) {
    self.itemCellViewController = itemCellViewController
    resetView(with: itemCellViewController.view as! ItemContentView)
  }

  private func resetView(with newItemContentView: ItemContentView) {
    assert(itemContentView == nil)
    newItemContentView.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(newItemContentView)

    [contentView.topAnchor.constraint(equalTo: newItemContentView.topAnchor),
     contentView.bottomAnchor.constraint(equalTo: newItemContentView.bottomAnchor),
     contentView.leftAnchor.constraint(equalTo: newItemContentView.leftAnchor),
     contentView.rightAnchor.constraint(equalTo: newItemContentView.rightAnchor)
      ].forEach { $0.isActive = true  }

    itemContentView = newItemContentView
  }
}
