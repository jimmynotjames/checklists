//
//  ScrollsWhenTooTall.swift
//  checklists
//

import SwiftUI

extension View {
  /// Lays this view out at least as tall as the space it is given, as a full-screen `VStack` with
  /// `Spacer`s expects, and scrolls it once its content is taller than that.
  func scrollsWhenTooTall() -> some View {
    GeometryReader { proxy in
      ScrollView {
        frame(maxWidth: .infinity, minHeight: proxy.size.height)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
  }
}
