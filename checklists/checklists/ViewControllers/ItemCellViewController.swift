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
  var itemContentView: ItemContentView {
    return self.view as! ItemContentView
  }

  init(item: Item) {
    self.item = item
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }

  override func loadView() {
    view = ItemContentView()
    itemContentView.delegate = self
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    itemContentView.item = item
  }
}

extension ItemCellViewController: ItemContentViewDelegate {
  func itemContentViewCheckboxButtonTapped(_ itemContentView: ItemContentView) {
    DBManager.write {
      item.toggleStatus()
    }
    itemContentView.item = item
  }

  func itemContentView(_ itemContentView: ItemContentView, nameFieldUpdatedWith name: String) {
    DBManager.write {
      item.name = name
    }
  }

  func itemContentView(_ itemContentView: ItemContentView, notesFieldUpdatedWith notes: String) {
    DBManager.write {
      item.notes = notes
    }
  }
}
