//
//  DonateViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 8/13/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit
import StoreKit
import ToastSwiftFramework

class DonateViewController: UITableViewController {
  let purchaseItemsSection = 0
  var loadedDonationProducts: [DonationProduct] = []

  var messageCellText: String?
  var messageCellReuseIdentifier: String = "MessageRow"

  enum State {
    case purchaseUnavailable
    case loading
    case productsLoaded(donationProducts: [DonationProduct])
    case errorLoadingProducts(errorCode: String)
    case purchasing
    case unsuccessfulPurchase(message: String)
    case successfulPurchase
    case deferredPurchase
  }
  var state: State = .loading {
    didSet {
      switch state {
      case .purchaseUnavailable:
        showToast(message: "Oops! Unable to donate because this device is not configured for In-App Purchase!")
      case .loading:
        showActivityIndicator()
      case .productsLoaded(let donationProducts):
        hideActivityIndicator()
        loadedDonationProducts = donationProducts
        reloadAnimated()
      case .errorLoadingProducts(let errorCode):
        showToast(message: "Oops! There was an issue getting donation options from the App Store (code: \(errorCode))")
      case .purchasing:
        showActivityIndicator()
      case .successfulPurchase:
        showToast(message: "Purchase successful! Thanks for your donation!!!")
      case .unsuccessfulPurchase(let errorMessage):
        showToast(message: "Oops! Something went wrong. Check your connection, maybe try again later? (System message: \(errorMessage))")
      case .deferredPurchase:
        showToast(message: "Your purchase is waiting for approval from your Approver.")
      }
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))

    let storeObserver = StoreObserver.shared

    if storeObserver.isAuthorizedForPayments {
      storeObserver.delegate = self
      storeObserver.fetchProducts()
      state = .loading
    } else {
      state = .purchaseUnavailable
    }
  }

  @objc func doneButtonTapped() {
    dismiss(animated: true, completion: nil)
  }

  private func reloadAnimated() {
    tableView.reloadSections([0], with: .fade)
  }

  private func showActivityIndicator() {
    tableView.isUserInteractionEnabled = false
    view.makeToastActivity(.center)
  }

  private func hideActivityIndicator() {
    tableView.isUserInteractionEnabled = true
    view.hideToastActivity()
  }

  private func showToast(message: String) {
    hideActivityIndicator()
    view.hideAllToasts()
    view.makeToast(message, duration: 10000.0, position: .center)
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    guard section == purchaseItemsSection else { assertionFailure(); return 0 }
    return loadedDonationProducts.count
  }

   override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "PurchaseItemRow", for: indexPath)
    guard
      let priceLabel = cell.viewWithTag(1) as? UILabel,
      let descriptionLabel = cell.viewWithTag(2) as? UILabel
      else { assertionFailure(); return UITableViewCell() }

    let index = indexPath.row
    priceLabel.text = loadedDonationProducts[index].priceString
    descriptionLabel.text = loadedDonationProducts[index].description
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let cell = tableView.cellForRow(at: indexPath) else { assertionFailure(); return }
    cell.isSelected = false
    guard indexPath.section == purchaseItemsSection else { return }
    StoreObserver.shared.purchaseDonationProduct(product: loadedDonationProducts[indexPath.row].product)
    state = .purchasing
  }
}

extension DonateViewController: StoreObserverDelegate {
  func errorRetrievingProducts(errorCode: StoreObserver.ErrorCode) {
    state = .errorLoadingProducts(errorCode: String(errorCode.rawValue))
  }

  func didReceiveProducts(donationProducts: [DonationProduct]) {
    state = .productsLoaded(donationProducts: donationProducts)
  }

  func transactionDidUpdate(with state: SKPaymentTransactionState, errorDescription: String?) {
    switch state {
    case .restored:
      assertionFailure() // This should never happen.
    case .deferred:
      self.state = .deferredPurchase
    case .purchasing:
      print("Purchasing...")
    case .purchased:
      self.state = .successfulPurchase
    case .failed:
      self.state = .unsuccessfulPurchase(message: errorDescription ?? "Unknown")
    // TODO: If user cancels, need to just have no message and remove activity indicator.
    default:
      assertionFailure()
      self.state = .productsLoaded(donationProducts: loadedDonationProducts)
    }
  }
}
