//
//  StoreObserver.swift
//  checklists
//
//  Created by Jimmy Ho on 8/13/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation
import StoreKit

class StoreObserver: NSObject, SKPaymentTransactionObserver {
  static let shared = StoreObserver()

  var isAuthorizedForPayments: Bool {
    return SKPaymentQueue.canMakePayments()
  }

  func paymentQueue(_ queue: SKPaymentQueue,updatedTransactions transactions: [SKPaymentTransaction]) {

  }
}
