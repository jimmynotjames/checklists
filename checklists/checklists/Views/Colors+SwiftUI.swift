//
//  Colors+SwiftUI.swift
//  checklists
//

import SwiftUI

/// SwiftUI `Color` accessors for the same generated color resources `Colors` already exposes as
/// `UIColor` for UIKit. Both read from the same colorsets in `Colors.xcassets`, so a screen can be
/// UIKit or SwiftUI without the palette drifting between them.
extension Colors {
  static let defaultBackgroundColor = Color(.defaultBackground)
  static let inactiveTextColor = Color(.inactiveText)
  static let darkBlueGrayColor = Color(.darkBlueGray)
  static let destructiveColor = Color(.salmonRed)
  static let successColor = Color(.success)
  static let warningColor = Color(.warning)
  static let shadowColor = Color(.shadow)
}

extension View {
  /// Applies the app's standard page background to a screen.
  ///
  /// Minimal by design, unlike `simple-recurring-budgets`'s `appBackground()`: this app has no custom
  /// nav-bar background requirement, so there's no `toolbarBackground` call to make here.
  func appBackground() -> some View {
    scrollContentBackground(.hidden)
      .background(Colors.defaultBackgroundColor.ignoresSafeArea())
  }
}
