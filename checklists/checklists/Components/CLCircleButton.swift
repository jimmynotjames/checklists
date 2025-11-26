//
//  CLCircleButton.swift
//  checklists
//
//  Created by Jimmy Ho on 11/20/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

import SwiftUI

// TODO: Do a better shadow effect on the button.

struct AddChecklistButton: View {
  let action: () -> Void

  var body: some View {
    CLCircleButton(
      iconName: "AddChecklistIcon",
      accessibilityLabel: "Add a new checklist",
      action: action
    )
  }
}

// SwiftUI counterpart to CLCircleButton
struct CLCircleButton: View {
  private let diameter: CGFloat = 60.0
  private let insetRadius: CGFloat = 10.0

  let iconName: String
  let accessibilityLabel: String
  let action: () -> Void

  init(iconName: String, accessibilityLabel: String, action: @escaping () -> Void) {
    self.iconName = iconName
    self.accessibilityLabel = accessibilityLabel
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      Image(uiImage: UIImage(named: iconName) ?? UIImage())
        .resizable()
        .scaledToFit()
        .padding(insetRadius)
        .frame(width: diameter, height: diameter)
        .background(Color(UIColor(.clear)))
        .clipShape(Circle())
        .overlay(
          Circle()
            .stroke(Color(UIColor(CLColors.defaultBackground)), lineWidth: 1)
            .shadow(color: .gray.opacity(0.6), radius: 1.0, x: 0.0, y: 1.0)
        )
        .accessibilityLabel(accessibilityLabel)
    }
    .buttonStyle(.plain)
  }
}

#Preview("CLCircleButtonView") {
  AddChecklistButton {
    // preview action
  }
  .padding()
}
