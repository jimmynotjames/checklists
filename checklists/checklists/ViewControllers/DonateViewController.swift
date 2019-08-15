//
//  DonateViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 8/13/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

class DonateViewController: UITableViewController {
  var purchaseItems: [(String, String)] = [] // (price, description)
  /* FOR TESTING
  var purchaseItems: [(String, String)] = [("$1.99", "Good app; worth a cup of bougie coffee."),
                                           ("$4.99", "This app saved me more than once!"),
                                           ("$9.99", "I'm a good person who's always kind to dogs.")]
  */

  var messageSection = 0
  var purchaseItemsSection = 1

  enum State {
    case loading
    case productsLoaded
    case errorLoadingProducts(message: String)
    case purchaseUnavailable
  }
  var state: State = .loading

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))

    if StoreObserver.shared.isAuthorizedForPayments {
      StoreObserver.shared.fetchProducts()
    } else {
      state = .purchaseUnavailable
    }
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
    case messageSection:
      switch state {
      case .loading, .errorLoadingProducts(_), .purchaseUnavailable:
        return 1
      case .productsLoaded:
        return 0
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
      if case .purchaseUnavailable = state {
        cell.selectionStyle = .none
      }
      return cell
    case messageSection:
      if indexPath.row == 0 {
        let cell: UITableViewCell
        switch state {
        case .loading:
          cell = tableView.dequeueReusableCell(withIdentifier: "LoadingMessageActivityIndicatorRow", for: indexPath)
        default:
          cell = tableView.dequeueReusableCell(withIdentifier: "ErrorMessageRow", for: indexPath)
        }
        cell.selectionStyle = .none
        
        guard let msgLabel = cell.viewWithTag(3) as? UILabel else { assertionFailure(); return UITableViewCell() }
        switch state {
        case .productsLoaded:
          assertionFailure()
        case .loading:
          msgLabel.text = "Loading possible donations..."
        case .purchaseUnavailable:
          msgLabel.text = "Oops! Unable to donate because this device is not configured for In-App Purchase!"
        case .errorLoadingProducts(let message):
          msgLabel.text = message
        }
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

    // TODO: may have to add more use cases here to ensure it doesn't do stuff on tap.
    guard indexPath.section == purchaseItemsSection else { return }
  }
}
