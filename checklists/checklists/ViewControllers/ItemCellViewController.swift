//
//  ItemCellViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 6/18/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

class ItemCellViewController: UIViewController {

  var item: Item? {
    didSet {
      itemContentView.item = item
    }
  }

  lazy var itemContentView: ItemContentView = {
    return self.view as! ItemContentView
  }()

  override func loadView() {
    view = ItemContentView()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
  }
}
