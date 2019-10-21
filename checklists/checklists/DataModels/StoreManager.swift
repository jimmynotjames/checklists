//
//  StoreObserver.swift
//  checklists
//
//  Created by Jimmy Ho on 8/13/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation
import StoreKit

// Copied/modified from https://developer.apple.com/documentation/storekit/in-app_purchase/offering_completing_and_restoring_in-app_purchases
extension SKProduct {
  /// - returns: The cost of the product formatted in the local currency.
  var regularPrice: String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = self.priceLocale
    return formatter.string(from: self.price) ?? "0.00"
  }
}

protocol StoreManagerDelegate: class {
  func errorRetrievingProducts(errorCode: StoreManager.ErrorCode)
  func didReceiveProducts(donationProducts: [DonationProduct])
  func transactionDidUpdate(with state: SKPaymentTransactionState, errorDescription: String?)
  func transactionDidCancel()
}

struct DonationProduct {
  let product: SKProduct
  let priceString: String
  let description: String
}

class StoreManager: NSObject {
  enum ErrorCode: Int {
    case zeroProductsReturned = 101
    case generalFetchError = 102
    case errorRetrievingProducts = 103
  }

  static let shared = StoreManager()

  weak var delegate: StoreManagerDelegate?

  var isAuthorizedForPayments: Bool {
    return SKPaymentQueue.canMakePayments()
  }

  private let productIdentifiers = Set(["com.jimmyho.checklists.donation.tierA",
                                        "com.jimmyho.checklists.donation.tierB",
                                        "com.jimmyho.checklists.donation.tierC"])
  private lazy var productRequest: SKProductsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
  private var loadedDonationProductsDict: [String: DonationProduct] = [:]

  func fetchProducts() {
    productRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
    productRequest.delegate = self
    productRequest.start()
  }

  func purchaseDonationProduct(product: SKProduct) {
    SKPaymentQueue.default().add(SKPayment(product: product))
  }
}

// MARK: - NSUserDefaults
// No way to 'restore' consumable purchases, so no way to give user a history, so we have to user NSUserDefaults,
// which won't survive app reinstall, but best we can do for now.

private let keyPrice = "price"
private let keyDate = "date"
private let purchaseHistoryKey = "reChecklistPurchaseHistory"

extension StoreManager {
  func archivePurchase(productId: String) {
    var updatedPurchases: [[String: Any]]
    if let purchases = UserDefaults.standard.object(forKey: purchaseHistoryKey) as? [[String: Any]] {
      updatedPurchases = purchases
    } else {
      updatedPurchases = []
    }
    guard let priceString = loadedDonationProductsDict[productId]?.priceString else { assertionFailure(); return }
    updatedPurchases.append([ keyPrice: priceString, keyDate: Date() ])
    UserDefaults.standard.setValue(updatedPurchases, forKey: purchaseHistoryKey)
  }

  func retrievePriorPurchases() -> [(priceString: String, date: Date)] {
    if let purchases = UserDefaults.standard.object(forKey: purchaseHistoryKey) as? [[String: Any]] {
      return purchases.compactMap { purchase in
        guard let priceString = purchase[keyPrice] as? String, let date = purchase[keyDate] as? Date else { assertionFailure(); return nil }
        return (priceString, date)
      }
    } else {
      return []
    }
  }
}

extension StoreManager: SKPaymentTransactionObserver {
  func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    transactions.forEach { transaction in
      switch transaction.transactionState {
      case .restored:
        assertionFailure() // This should never happen.
      case .purchasing, .deferred:
        print("Purchasing or Deferred...")
      case .purchased:
        SKPaymentQueue.default().finishTransaction(transaction)
        archivePurchase(productId: transaction.payment.productIdentifier)
      case .failed:
        SKPaymentQueue.default().finishTransaction(transaction)
      default:
        assertionFailure()
      }
      if let error = transaction.error as NSError?, SKError.paymentCancelled.rawValue == error.code {
        delegate?.transactionDidCancel()
      } else {
        delegate?.transactionDidUpdate(with: transaction.transactionState, errorDescription: transaction.error?.localizedDescription)
      }
    }
  }
}

extension StoreManager: SKProductsRequestDelegate {
  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    let products = response.products
    guard products.count > 0 else {
      print("Zero products returned")
      delegate?.errorRetrievingProducts(errorCode: .zeroProductsReturned)
      return
    }
    let donationProducts = products.map { product in
        DonationProduct(product: product,
                        priceString: product.regularPrice,
                        description: product.localizedDescription)
    }.sorted { (product1, product2) -> Bool in
      return product1.product.productIdentifier < product2.product.productIdentifier
    }

    loadedDonationProductsDict = [:]
    donationProducts.forEach { donationProduct in
      loadedDonationProductsDict[donationProduct.product.productIdentifier] = donationProduct
    }

    delegate?.didReceiveProducts(donationProducts: donationProducts)
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    print("Error retrieving products - didFailWithError: \(error)")
    delegate?.errorRetrievingProducts(errorCode: .errorRetrievingProducts)
  }
}
