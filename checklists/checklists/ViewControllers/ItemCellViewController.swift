//
//  ItemCellViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 6/18/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

protocol ItemCellViewControllerDelegate: class {
  func cellHeightRequiresRefresh(animated: Bool)
  func insertNewItemAfter(itemId: String)
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
    itemContentView.addAnotherButtonTappedAction = { [weak self] in
      guard let `self` = self else { assertionFailure(); return }
      self.delegate?.insertNewItemAfter(itemId: self.item.id)
    }
    setExpandedState()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    itemContentView.item = item
  }

  func startEditing() {
    itemContentView.startEditing()
  }
}

extension ItemCellViewController: ItemContentViewDelegate {
  func itemContentViewDidFinishEditing(_ itemContentView: ItemContentView) {
    setExpandedState()
    delegate?.cellHeightRequiresRefresh(animated: true)
  }

  func itemContentViewCheckboxButtonTapped(_ itemContentView: ItemContentView) {
    DBManager.write {
      item.toggleStatus()
    }
    itemContentView.item = item
  }

  func itemContentViewNameFieldDidBeginEditing(_ itemContentView: ItemContentView) {
    setExpandedState(isExpandedOverride: true)
    delegate?.cellHeightRequiresRefresh(animated: true)
  }

  func itemContentViewHeightUpdated(_ itemContentView: ItemContentView) {
    delegate?.cellHeightRequiresRefresh(animated: false)
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
