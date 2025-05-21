//
//  Colors.swift
//  checklists
//
//  Created by Jimmy Ho on 7/27/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit
import SwiftUI

class CLUIColors {
  static let defaultBackground = UIColor(named: "defaultBackground") ?? .white
  static let inactiveText = UIColor(named: "inactiveText") ?? .darkGray

  static let darkBlueGray = UIColor(named: "darkBlueGray") ?? .darkGray
  static let teal = UIColor(named: "teal") ?? .darkGray
  static let salmonRed = UIColor(named: "salmonRed") ?? .red
  static let darkPurple = UIColor(named: "darkPurple") ?? .purple
}

class CLColors {
  static let defaultBackground = Color("defaultBackground")
  static let inactiveText = Color("inactiveText")
  static let placeholderText  = Color("placeholderText")

  static let darkBlueGray = Color("darkBlueGray")
  static let teal = Color("teal") // Default for buttons, nav bar, and icons.
  static let salmonRed = Color("salmonRed")
  static let darkPurple = Color("darkPurple")
}
