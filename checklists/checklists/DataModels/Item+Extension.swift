//
//  Item+Extension.swift
//  checklists
//
//  Created by Jimmy Ho on 5/10/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation

extension Item {
  // Using an enum instead of a Bool because eventually I want to add 'deleted'
  enum ItemStatus: String {
    case unchecked = "unchecked" // NOTE: Also used as default value in core data schema file and in other places.
    case checked = "checked"

    var coreDataValue: String {
      return rawValue
    }

    static let defaultValue: ItemStatus = .unchecked
  }

  var isChecked: Bool {
    return itemStatus == .checked
  }

  var itemStatus: ItemStatus {
    get {
      guard
        let statusString = statusString,
        let status = ItemStatus(rawValue: statusString) else { assertionFailure(); return .unchecked }

        return status
    }
    set {
      statusString = newValue.rawValue
    }
  }
}
