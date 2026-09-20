//
//  Colors.swift
//  checklists
//
//  Created by Jimmy Ho on 7/27/19.
//

import UIKit

class Colors {
  static let defaultBackground = UIColor(resource: .defaultBackground)
  static let inactiveText = UIColor(resource: .inactiveText)
  static let primaryText = UIColor(resource: .primaryText)
  static let placeholderText = UIColor(resource: .placeholderText)

  static let darkBlueGray = UIColor(resource: .darkBlueGray)

  /// The app's accent color, also wired up as the global tint via
  /// `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`. Prefer `UIColor.tintColor` at call sites.
  /// Two callers can't: `CircularPercentStatusIcon` needs a concrete `CGColor` for a `CALayer`,
  /// and `CLButton` resolves its colors through a `UIButton.Configuration`, which runs before the
  /// button has a window to inherit a tint from.
  static let accent = UIColor(resource: .accent)
  static let salmonRed = UIColor(resource: .salmonRed)
  static let darkPurple = UIColor(resource: .darkPurple)

  /// The destructive-action color, matching `Colors.destructiveColor` on the SwiftUI side.
  static let destructive = UIColor(resource: .salmonRed)
}
