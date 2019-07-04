//
//  ChecklistViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 6/8/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

private let itemsSection = 0
private let itemCellReuseIdentifier = "ItemCell"

class ChecklistViewController: UITableViewController {
  var checklist: Checklist! // Expected to be set on seque or right after init(). Behavior undefined if this is set/reset after viewDidLoad().

  /*
   Architectural Discussion:
   One option was to have each Cell hold a view controller and reset each cell+VC on cell reuse.
   Issue with that is preserving view state (such as expanded/collapsed, editing mode, etc.). If
   user scrolls it off screen, I'd have to capture it somehow and no easy way without maintaining
   an array.

   Another option was to have an array view controllers. This is cleaner but since users can
   arbitrarily reorder and remove Items, I would have to remember to update the VC array everytime
   I update the Checklist.items. Not that hard, but still.

   To account for above issues, easier to use a dictionary. This way, mapping will always sync up.
   */
  var itemViewControllersDict: [ Item: ItemCellViewController ] = [:]

  override func viewDidLoad() {
    super.viewDidLoad()

    navigationItem.title = checklist.name

    tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: itemCellReuseIdentifier)

    self.navigationItem.rightBarButtonItem = self.editButtonItem
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return checklist.items.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == itemsSection {
      guard let cell = tableView.dequeueReusableCell(withIdentifier: itemCellReuseIdentifier, for: indexPath) as? ItemTableViewCell else { assertionFailure(); return UITableViewCell() }
      guard indexPath.row >= 0 && indexPath.row < checklist.items.count else { assertionFailure(); return UITableViewCell() }

      let item = checklist.items[indexPath.row]
      let itemCellViewController = itemViewControllersDict[item] ?? ItemCellViewController(item: item)
      itemViewControllersDict[item] = itemCellViewController
      cell.setViewController(with: itemCellViewController)
      return cell
    } else {
      assertionFailure()
      return UITableViewCell()
    }
  }

  override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
    return false
  }

  override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    if let childViewController = (cell as? ItemTableViewCell)?.itemCellViewController {
      addChild(childViewController)
      childViewController.didMove(toParent: self)
    }
  }

  override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    if let childViewController = (cell as? ItemTableViewCell)?.itemCellViewController {
      childViewController.willMove(toParent: nil)
      childViewController.removeFromParent()
    }
  }

  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    guard indexPath.section == 0 else { assertionFailure(); return }
    if editingStyle == .delete {
      checklist.remove(at: indexPath.row)
      tableView.deleteRows(at: [indexPath], with: .fade)
    } else if editingStyle == .insert {
      assertionFailure()
    }
  }

  // TODO: This may not be necessary if I don't do a second section.
  override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
    guard indexPath.section == 0 else { assertionFailure(); return .none }
    return .delete
  }

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    guard indexPath.section == 0 else { assertionFailure(); return false } // TODO: May not be necessary if I don't do second section.
    return true
  }

  override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    checklist.moveItem(from: sourceIndexPath.row, to: destinationIndexPath.row)
  }
}
