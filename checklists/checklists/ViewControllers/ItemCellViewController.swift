//
//  ItemCellViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 6/18/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

class ItemCellViewController: UIViewController {

  let item: Item

  lazy var itemContentView: ItemContentView = {
    return self.view as! ItemContentView
  }()

  init(item: Item) {
    self.item = item
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }

  override func loadView() {
    view = ItemContentView()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    itemContentView.item = item
  }
}
