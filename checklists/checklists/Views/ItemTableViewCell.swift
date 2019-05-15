//
//  ItemTableViewCell.swift
//  checklists
//
//  Created by Jimmy Ho on 5/11/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

class ItemTableViewCell: UITableViewCell {
  private let itemContentView = ItemContentView()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    contentView.addSubview(itemContentView)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("This init() not supported.")
  }

  // TODO: Delete this template code?
  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
  }
}
