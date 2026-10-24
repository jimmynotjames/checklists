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
  static let primaryTextColor = Color(.primaryText)
  static let inactiveTextColor = Color(.inactiveText)
  /// The menu panel and toast card.
  static let darkBlueGrayColor = Color(.darkBlueGray)
  /// Text and icons drawn on `darkBlueGrayColor`.
  static let panelForegroundColor = Color(.panelForeground)
  /// A raised surface on the page: Form rows and the floating add button.
  static let surfaceColor = Color(.surface)
  static let destructiveColor = Color(.salmonRed)
  static let accentFillColor = Color(.accentFill)
  static let destructiveFillColor = Color(.destructiveFill)
  static let successColor = Color(.success)
  static let warningColor = Color(.warning)
  static let shadowColor = Color(.shadow)
}

extension View {
  /// Puts grouped `Form` rows on `surface` rather than the system cell color, which in dark mode
  /// is a neutral gray against the app's tinted page. Apply it to the sections, not the `Form`.
  func formRowBackground() -> some View {
    listRowBackground(Colors.surfaceColor)
  }

  /// Applies the app's standard page background to a screen. No `toolbarBackground`: this app has
  /// no custom nav-bar background.
  func appBackground() -> some View {
    scrollContentBackground(.hidden)
      .background(Colors.defaultBackgroundColor.ignoresSafeArea())
  }
}
