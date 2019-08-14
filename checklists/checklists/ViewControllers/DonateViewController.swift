//
//  DonateViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 8/13/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

class DonateViewController: UITableViewController {
  // var purchaseItems: [(String, String)] = [] // (price, description)
  var purchaseItems: [(String, String)] = [("$1.99", "Good app; worth a cup of bougie coffee."),
                                           ("$4.99", "This app saved me more than once!"),
                                           ("$9.99", "I'm a good person who's always kind to dogs.")]

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
  }

  @objc func doneButtonTapped() {
    dismiss(animated: true, completion: nil)
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
    return purchaseItems.count
  }

   override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

    let cell = tableView.dequeueReusableCell(withIdentifier: "PurchaseItemRow", for: indexPath)
    let index = indexPath.row
    guard
      let priceLabel = cell.viewWithTag(1) as? UILabel,
      let descriptionLabel = cell.viewWithTag(2) as? UILabel
      else { assertionFailure(); return UITableViewCell() }

    priceLabel.text = purchaseItems[index].0
    descriptionLabel.text = purchaseItems[index].1

    return cell
   }

   override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return false
   }

   // Override to support conditional rearranging of the table view.
   override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    return false
   }
}
