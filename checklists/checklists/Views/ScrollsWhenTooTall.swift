//
//  ScrollsWhenTooTall.swift
//  checklists
//

import SwiftUI

extension View {
  /// Lays this view out at least as tall as the space it is given, as a full-screen `VStack` with
  /// `Spacer`s expects, and scrolls it once its content is taller than that: at the accessibility
  /// text sizes a screen's text and buttons outgrow a small phone, and without scrolling its last
  /// buttons end up off screen with no way to reach them. At sizes where it fits it does not scroll
  /// or bounce.
  func scrollsWhenTooTall() -> some View {
    GeometryReader { proxy in
      ScrollView {
        frame(maxWidth: .infinity, minHeight: proxy.size.height)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
  }
}
