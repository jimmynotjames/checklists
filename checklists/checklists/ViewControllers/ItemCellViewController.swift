//
//  ItemCellViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 6/18/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

protocol ItemCellViewControllerDelegate: class {
  func cellHeightRequiresRefresh()
}

class ItemCellViewController: UIViewController {

  weak var delegate: ItemCellViewControllerDelegate?

  private let item: Item
  private var itemContentView: ItemContentView {
    return self.view as! ItemContentView
  }
  private var isExpanded: Bool?

  init(item: Item, delegate: ItemCellViewControllerDelegate) {
    self.item = item
    self.delegate = delegate
    super.init(nibName: nil, bundle: nil)
  }

  func setExpandedState(isExpandedOverride: Bool? = nil) {
    let newIsExpanded = isExpandedOverride != nil ? isExpandedOverride! : item.notes?.count ?? 0 > 0
    if isExpanded == nil || isExpanded! != newIsExpanded  {
      itemContentView.updateTextViewHeight(isExpanded: newIsExpanded)
    }
    isExpanded = newIsExpanded
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
    //  setExpandedState()
    setExpandedState(isExpandedOverride: false)
  }
}

extension ItemCellViewController: ItemContentViewDelegate {
  func itemContentViewDidFinishEditing(_ itemContentView: ItemContentView) {
    setExpandedState()
    delegate?.cellHeightRequiresRefresh()
  }

  func itemContentViewCheckboxButtonTapped(_ itemContentView: ItemContentView) {
    DBManager.write {
      item.toggleStatus()
    }
    itemContentView.item = item
  }

  func itemContentViewNameFieldDidBeginEditing(_ itemContentView: ItemContentView) {
    setExpandedState(isExpandedOverride: true)
    delegate?.cellHeightRequiresRefresh()
  }

  func itemContentViewHeightUpdated(_ itemContentView: ItemContentView) {
    delegate?.cellHeightRequiresRefresh()
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
