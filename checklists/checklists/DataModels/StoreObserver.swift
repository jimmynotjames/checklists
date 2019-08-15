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
}

struct DonationProduct {
  let priceString: String
  let description: String
  let productId: String
}

class StoreObserver: NSObject, SKPaymentTransactionObserver {
  enum ErrorCode: Int {
    case zeroProductsReturned = 101
    case generalFetchError = 102
  }

  static let shared = StoreObserver()

  weak var delegate: StoreObserverDelegate?

  var isAuthorizedForPayments: Bool {
    return SKPaymentQueue.canMakePayments()
  }

  private let productIdentifiers = Set(["com.jimmyho.checklists.donation.tier2"])
  private lazy var productRequest: SKProductsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)

  func fetchProducts() {
    productRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
    productRequest.delegate = self
    productRequest.start()
  }

  func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {

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
        return DonationProduct(priceString: product.regularPrice,
                               description: product.localizedDescription,
                               productId: product.productIdentifier)
    }
    delegate?.didReceiveProducts(donationProducts: donationProducts)
  }
}


/*
 TODO: REMOVE
 FOR TESTING
 var purchaseItems: [(String, String)] = [("$1.99", "Good app; worth a cup of bougie coffee."),
 ("$4.99", "This app saved me more than once!"),
 ("$9.99", "I'm a good person who's always kind to dogs.")]
 */

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
