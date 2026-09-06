//
//  Colors+SwiftUI.swift
//  checklists
//

import SwiftUI

/// SwiftUI `Color` accessors for the same named colors `Colors` already exposes as
/// `UIColor` for UIKit. Both read from the same colorsets in `Colors.xcassets`, so a
/// screen can be UIKit or SwiftUI without the palette drifting between them.
extension Colors {
  static let tealColor = Color("teal")
  static let defaultBackgroundColor = Color("defaultBackground")
  static let inactiveTextColor = Color("inactiveText")
  static let darkBlueGrayColor = Color("darkBlueGray")
  static let salmonRedColor = Color("salmonRed")
}

extension View {
  /// Applies the app's standard page background to a screen.
  ///
  /// Minimal by design, unlike budgets1's `appBackground()`: this app has no custom
  /// nav-bar background requirement, so there's no `toolbarBackground` call to make here.
  func appBackground() -> some View {
    scrollContentBackground(.hidden)
      .background(Colors.defaultBackgroundColor.ignoresSafeArea())
  }
}
