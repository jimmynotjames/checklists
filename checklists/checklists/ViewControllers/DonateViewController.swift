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

  var errorMessageSection = 0
  var purchaseItemsSection = 1
  var isShowingPurchaseUnavailable = false

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))

    isShowingPurchaseUnavailable = !StoreObserver.shared.isAuthorizedForPayments
  }

  @objc func doneButtonTapped() {
    dismiss(animated: true, completion: nil)
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case purchaseItemsSection:
      return purchaseItems.count
    case errorMessageSection:
      if isShowingPurchaseUnavailable {
        return 1
      }
    default:
      assertionFailure()
    }
    return 0
  }

   override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

    switch indexPath.section {
    case purchaseItemsSection:
      let cell = tableView.dequeueReusableCell(withIdentifier: "PurchaseItemRow", for: indexPath)
      let index = indexPath.row
      guard
        let priceLabel = cell.viewWithTag(1) as? UILabel,
        let descriptionLabel = cell.viewWithTag(2) as? UILabel
        else { assertionFailure(); return UITableViewCell() }

      priceLabel.text = purchaseItems[index].0
      descriptionLabel.text = purchaseItems[index].1
      if isShowingPurchaseUnavailable {
        cell.selectionStyle = .none
      }
      return cell
    case errorMessageSection:
      let cell = tableView.dequeueReusableCell(withIdentifier: "ErrorMessageRow", for: indexPath)
      cell.selectionStyle = .none
      if isShowingPurchaseUnavailable {
        guard let errorMsgLabel = cell.viewWithTag(3) as? UILabel else { assertionFailure(); return UITableViewCell() }
        errorMsgLabel.text = "Oops! Unable to donate because this device is not configured for In-App Purchase!"
        return cell
      }
    default:
      assertionFailure()
    }
    assertionFailure()
    return UITableViewCell()
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let cell = tableView.cellForRow(at: indexPath) else { assertionFailure(); return }
    cell.isSelected = false

    guard indexPath.section == purchaseItemsSection && !isShowingPurchaseUnavailable else { return }
  }
}
