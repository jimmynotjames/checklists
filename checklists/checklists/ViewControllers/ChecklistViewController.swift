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

  override func viewDidLoad() {
    super.viewDidLoad()

    navigationItem.title = checklist.name

    tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: itemCellReuseIdentifier)

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem
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

      cell.setContentView(with: checklist.items[indexPath.row])
      return cell
    } else {
      assertionFailure()
      return UITableViewCell()
    }
  }

  override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
    return false
  }

  /*
   // Override to support conditional editing of the table view.
   override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
   // Return false if you do not want the specified item to be editable.
   return true
   }
   */

  /*
   // Override to support editing the table view.
   override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
   if editingStyle == .delete {
   // Delete the row from the data source
   tableView.deleteRows(at: [indexPath], with: .fade)
   } else if editingStyle == .insert {
   // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
   }
   }
   */

  /*
   // Override to support rearranging the table view.
   override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

   }
   */

  /*
   // Override to support conditional rearranging of the table view.
   override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
   // Return false if you do not want the item to be re-orderable.
   return true
   }
   */
}
