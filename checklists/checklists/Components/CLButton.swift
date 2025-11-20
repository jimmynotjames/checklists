//
//  CLButton.swift
//  checklists
//
//  Created by Jimmy Ho on 11/20/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

import SwiftUI

struct CLButtonStyle: ButtonStyle {
  var normalColor: Color = Color(.clear)
  var highlightedColor: Color = Color(CLColors.teal)
  var cornerRadius: CGFloat = 4.0
  var borderWidth: CGFloat = 1.0

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundColor(configuration.isPressed ? normalColor : highlightedColor)
      .padding(.vertical, 14)
      .padding(.horizontal, 14)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(highlightedColor, lineWidth: borderWidth)
          .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              .fill(configuration.isPressed ? highlightedColor : normalColor)
          )
      )
  }
}

/// Convenience SwiftUI button that applies CLButtonStyle by default.
struct CLButton<Label: View>: View {
  let action: () -> Void
  let label: () -> Label

  init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
    self.action = action
    self.label = label
  }

  var body: some View {
    Button(action: action, label: label)
      .buttonStyle(CLButtonStyle())
  }
}

#Preview("CLButtonSwiftUI") {
  VStack(spacing: 12) {
    CLButton(action: {}) {
      Text("Tap Me")
        .font(.body)
    }
    Button("Plain Usage") {}
      .buttonStyle(CLButtonStyle())
  }
  .padding()
  .background(Color(.systemBackground))
}
