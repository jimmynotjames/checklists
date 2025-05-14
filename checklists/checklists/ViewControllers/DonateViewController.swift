//
//  DonateViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 8/13/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit
import StoreKit
import Toast

class DonateViewController: UITableViewController {
  let purchaseItemsSection = 0
  let infoSection = 1
  let purchaseHistorySection = 2

  var loadedDonationProducts: [DonationProduct] = []
  var purchaseHistoryItems: [(priceString: String, date: Date)] = StoreManager.shared.retrievePriorPurchases()

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
        purchaseHistoryItems = StoreManager.shared.retrievePriorPurchases()
        tableView.reloadSections([purchaseHistorySection], with: .fade)
      case .unsuccessfulPurchase(let errorMessage):
        showToast(message: "Oops! Something went wrong. Check your connection, maybe try again later? (System message: \(errorMessage))")
      case .deferredPurchase:
        showToast(message: "Your purchase is waiting for approval from your Approver.")
      }
    }
  }

  private lazy var dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short
    return dateFormatter
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))

    let storeManager = StoreManager.shared

    if storeManager.isAuthorizedForPayments {
      storeManager.delegate = self
      storeManager.fetchProducts()
      state = .loading
    } else {
      state = .purchaseUnavailable
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    AnalyticsManager.logDonatePageViewed()
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
    UIAccessibility.post(notification: .screenChanged, argument: message)
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 3
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case purchaseItemsSection:
      return loadedDonationProducts.count
    case infoSection:
      return 1
    case purchaseHistorySection:
      return purchaseHistoryItems.count
    default:
      assertionFailure()
    }
    return 0
  }

   override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell: UITableViewCell
    switch indexPath.section {
    case purchaseItemsSection:
      cell = tableView.dequeueReusableCell(withIdentifier: "PurchaseItemRow", for: indexPath)
      guard
        let priceLabel = cell.viewWithTag(1) as? UILabel,
        let descriptionLabel = cell.viewWithTag(2) as? UILabel
        else { assertionFailure(); return UITableViewCell() }

      let index = indexPath.row
      priceLabel.text = loadedDonationProducts[index].priceString
      descriptionLabel.text = loadedDonationProducts[index].description
    case infoSection:
      cell = tableView.dequeueReusableCell(withIdentifier: "InfoRow", for: indexPath)
    case purchaseHistorySection:
      cell = tableView.dequeueReusableCell(withIdentifier: "PurchasedItemRow", for: indexPath)
      guard
        let priceLabel = cell.viewWithTag(1) as? UILabel,
        let descriptionLabel = cell.viewWithTag(2) as? UILabel
        else { assertionFailure(); return UITableViewCell() }

      priceLabel.text = purchaseHistoryItems[indexPath.row].priceString
      descriptionLabel.text = dateFormatter.string(from: purchaseHistoryItems[indexPath.row].date)
    default:
      assertionFailure()
      cell = UITableViewCell()
    }
    return cell
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    if section == purchaseHistorySection && purchaseHistoryItems.count > 0 {
      return "PRIOR DONATIONS"
    } else {
      return nil
    }
  }

  override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    guard
      let view = view as? UITableViewHeaderFooterView,
      let textLabel = view.textLabel
      else { assertionFailure(); return }
    let backgroundView = UIView()
    backgroundView.backgroundColor = .clear
    view.backgroundView = backgroundView
    view.tintColor = CLUIColors.defaultBackground // Not clear so if header sticks to top, things don't overlap while scrolling up.
    textLabel.font = .systemFont(ofSize: 15.0)
    textLabel.textColor = CLUIColors.inactiveText
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let cell = tableView.cellForRow(at: indexPath) else { assertionFailure(); return }
    cell.isSelected = false
    guard indexPath.section == purchaseItemsSection else { return }
    let product = loadedDonationProducts[indexPath.row].product
    StoreManager.shared.purchaseDonationProduct(product: product)
    state = .purchasing
    AnalyticsManager.logDonation(productId: product.productIdentifier)
  }
}

// As of Xcode 11/iOS 13, events from StoreKit seems to happening off main thread, so need to wrap stuff.
extension DonateViewController: StoreManagerDelegate {
  func errorRetrievingProducts(errorCode: StoreManager.ErrorCode) {
    DispatchQueue.main.async {
      self.state = .errorLoadingProducts(errorCode: String(errorCode.rawValue))
      AnalyticsManager.logProductLoadingError(errorMessage: String(errorCode.rawValue))
    }
  }

  func didReceiveProducts(donationProducts: [DonationProduct]) {
    DispatchQueue.main.async {
      self.state = .productsLoaded(donationProducts: donationProducts)
    }
  }

  func transactionDidUpdate(with state: SKPaymentTransactionState, errorDescription: String?) {
    DispatchQueue.main.async {
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
        let message = errorDescription ?? "Unknown"
        self.state = .unsuccessfulPurchase(message: message)
        AnalyticsManager.logPurchaseError(errorMessage: message)
      default:
        assertionFailure()
        self.state = .productsLoaded(donationProducts: self.loadedDonationProducts)
      }
    }
  }

  func transactionDidCancel() {
    DispatchQueue.main.async {
      self.state = .productsLoaded(donationProducts: self.loadedDonationProducts)
    }
  }
}
