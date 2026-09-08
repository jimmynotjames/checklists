//
//  Colors.swift
//  checklists
//
//  Created by Jimmy Ho on 7/27/19.
//

import UIKit

class Colors {
  static let defaultBackground = UIColor(named: "defaultBackground") ?? .white
  static let inactiveText = UIColor(named: "inactiveText") ?? .darkGray
  static let primaryText = UIColor(named: "primaryText") ?? .black
  static let placeholderText = UIColor(named: "placeholderText") ?? .lightGray

  static let darkBlueGray = UIColor(named: "darkBlueGray") ?? .darkGray

  /// The app's accent color, also wired up as the global tint via
  /// `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`. Prefer `UIColor.tintColor` at call sites;
  /// this exists for `CircularPercentStatusIcon`, which needs a concrete `CGColor`.
  static let accent = UIColor(named: "AccentColor") ?? .systemBlue
  static let salmonRed = UIColor(named: "salmonRed") ?? .red
  static let darkPurple = UIColor(named: "darkPurple") ?? .purple
}
