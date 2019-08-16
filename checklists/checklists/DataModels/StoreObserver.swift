//
//  StoreObserver.swift
//  checklists
//
//  Created by Jimmy Ho on 8/13/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation
import StoreKit

protocol StoreObserverDelegate: class {
  func errorRetrievingProducts(errorCode: StoreObserver.ErrorCode)
  func didReceiveProducts(donationProducts: [DonationProduct])
  func transactionDidUpdate(with state: SKPaymentTransactionState, errorDescription: String?)
}

struct DonationProduct {
  let product: SKProduct
  let priceString: String
  let description: String
}

class StoreObserver: NSObject {
  enum ErrorCode: Int {
    case zeroProductsReturned = 101
    case generalFetchError = 102
  }

  static let shared = StoreObserver()

  weak var delegate: StoreObserverDelegate?

  var isAuthorizedForPayments: Bool {
    return SKPaymentQueue.canMakePayments()
  }

  private let productIdentifiers = Set(["com.jimmyho.checklists.donation.tierA",
                                        "com.jimmyho.checklists.donation.tierB",
                                        "com.jimmyho.checklists.donation.tierC"])
  private lazy var productRequest: SKProductsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)

  func fetchProducts() {
    productRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
    productRequest.delegate = self
    productRequest.start()
  }

  func purchaseDonationProduct(product: SKProduct) {
    SKPaymentQueue.default().add(SKPayment(product: product))
  }
}

extension StoreObserver: SKPaymentTransactionObserver {
  func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    transactions.forEach { transaction in
      switch transaction.transactionState {
      case .restored:
        assertionFailure() // This should never happen.
      case .purchasing, .deferred:
        print("Purchasing or Deferred...")
      case .purchased, .failed:
        SKPaymentQueue.default().finishTransaction(transaction)
        // TODO: If user navigates away from page, and then this returns, we should show something, like an alert or something. And maybe show history of donations?
      default:
        assertionFailure()
      }
      delegate?.transactionDidUpdate(with: transaction.transactionState, errorDescription: transaction.error?.localizedDescription)
    }
  }
}

extension StoreObserver: SKProductsRequestDelegate {
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
    delegate?.didReceiveProducts(donationProducts: donationProducts)
  }
}

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
