//
//  Colors.swift
//  checklists
//
//  Created by Jimmy Ho on 7/27/19.
//

import UIKit

class Colors {
  /// The page background. Never a foreground: text and icons on the panel use
  /// `panelForegroundColor`.
  static let defaultBackground = UIColor(resource: .defaultBackground)
  static let inactiveText = UIColor(resource: .inactiveText)
  static let primaryText = UIColor(resource: .primaryText)
  static let placeholderText = UIColor(resource: .placeholderText)

  static let darkBlueGray = UIColor(resource: .darkBlueGray)

  /// The app's accent color, also wired up as the global tint via
  /// `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`. Prefer `UIColor.tintColor` at call sites.
  /// Some callers can't: `CircularPercentStatusIcon` needs a concrete `CGColor` for a `CALayer`,
  /// and `CLButton` resolves its colors through a `UIButton.Configuration`, which runs before the
  /// button has a window to inherit a tint from.
  static let accent = UIColor(resource: .accent)
  static let salmonRed = UIColor(resource: .salmonRed)
  static let darkPurple = UIColor(resource: .darkPurple)

  /// The destructive-action color, matching `Colors.destructiveColor` on the SwiftUI side.
  static let destructive = UIColor(resource: .salmonRed)

  /// Swipe-action backgrounds, which carry a white glyph. `accent` and `destructive` are tuned to
  /// read as text on the page, which can leave them too light behind white.
  static let accentFill = UIColor(resource: .accentFill)
  static let destructiveFill = UIColor(resource: .destructiveFill)
}
