//
//  DonateViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 8/13/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit
import StoreKit

class DonateViewController: UITableViewController {
  var messageSection = 0
  var purchaseItemsSection = 1

  enum State {
    case loading
    case productsLoaded(donationProducts: [DonationProduct])
    case errorLoadingProducts(message: String)
    case purchaseUnavailable
  }
  var state: State = .loading

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))

    let storeObserver = StoreObserver.shared

    if storeObserver.isAuthorizedForPayments {
      storeObserver.delegate = self
      storeObserver.fetchProducts()
    } else {
      state = .purchaseUnavailable
    }
  }

  @objc func doneButtonTapped() {
    dismiss(animated: true, completion: nil)
  }

  private func setError(with message: String) {
    state = .errorLoadingProducts(message: message)
    reloadAnimated()
  }

  private func setDonationProducts(donationProducts: [DonationProduct]) {
    state = .productsLoaded(donationProducts: donationProducts)
    reloadAnimated()
  }

  private func reloadAnimated() {
    tableView.reloadSections([0, 1], with: .fade)
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case purchaseItemsSection:
      switch state {
      case .productsLoaded(let donationProducts):
        return donationProducts.count
      default:
        return 0
      }
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

      switch state {
      case .productsLoaded(let donationProducts):
        priceLabel.text = donationProducts[index].priceString
        descriptionLabel.text = donationProducts[index].description
      default:
        assertionFailure()
      }

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
          cell = tableView.dequeueReusableCell(withIdentifier: "MessageRow", for: indexPath)
        }
        cell.selectionStyle = .none
        
        guard let msgLabel = cell.viewWithTag(3) as? UILabel else { assertionFailure(); return UITableViewCell() }
        switch state {
        case .productsLoaded:
          assertionFailure()
        case .loading:
          msgLabel.text = "Loading donation options..."
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
    guard indexPath.section == purchaseItemsSection else { return }
    switch state {
    case .productsLoaded(let donationProducts):
      StoreObserver.shared.purchaseDonationProduct(product: donationProducts[indexPath.row].product)
    default:
      assertionFailure()
    }
  }
}

extension DonateViewController: StoreObserverDelegate {
  func errorRetrievingProducts(errorCode: StoreObserver.ErrorCode) {
    setError(with: "Oops! There was an issue getting donation options from the App Store (code: \(errorCode.rawValue))")
  }

  func didReceiveProducts(donationProducts: [DonationProduct]) {
    setDonationProducts(donationProducts: donationProducts)
  }

  func transactionDidUpdate(with state: SKPaymentTransactionState, errorDescription: String?) {
    // TODO
  }
}
