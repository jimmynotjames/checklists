//
//  StatusIconView.swift
//  checklists
//

import SwiftUI
import UIKit

/// SwiftUI wrapper around the existing UIKit `CircularPercentStatusIcon`.
///
/// Kept as a UIKit wrapper rather than redrawn natively in SwiftUI because
/// `CircularPercentStatusIcon` is shared with the still-UIKit `ChecklistViewController`'s
/// header icon — one implementation, so the ring-drawing math and the accessibility value
/// ("Checklist X percent complete") cannot drift apart between the two screens.
struct StatusIconView: UIViewRepresentable {
  var percentageComplete: CGFloat
  var iconType: CircularPercentStatusIcon.IconType = .row
  /// Multiplies the icon's size; see `CircularPercentStatusIcon.scale`.
  var scale: CGFloat = 1.0

  func makeUIView(context _: Context) -> CircularPercentStatusIcon {
    let icon = CircularPercentStatusIcon(iconType: iconType)
    icon.scale = scale
    icon.percentageComplete = percentageComplete
    return icon
  }

  func updateUIView(_ uiView: CircularPercentStatusIcon, context _: Context) {
    uiView.scale = scale
    uiView.percentageComplete = percentageComplete
  }

  func sizeThatFits(_: ProposedViewSize, uiView _: CircularPercentStatusIcon, context _: Context) -> CGSize? {
    let diameter = CircularPercentStatusIcon.diameter(for: iconType, scale: scale)
    return CGSize(width: diameter, height: diameter)
  }
}

#if DEBUG
  #Preview("Row") {
    HStack {
      StatusIconView(percentageComplete: 0)
      StatusIconView(percentageComplete: 0.33)
      StatusIconView(percentageComplete: 0.83)
      StatusIconView(percentageComplete: 1)
    }
    .padding()
  }

  #Preview("Row, scaled 1.5x") {
    HStack {
      StatusIconView(percentageComplete: 0, scale: 1.5)
      StatusIconView(percentageComplete: 0.33, scale: 1.5)
      StatusIconView(percentageComplete: 0.83, scale: 1.5)
      StatusIconView(percentageComplete: 1, scale: 1.5)
    }
    .padding()
  }

  #Preview("Header") {
    StatusIconView(percentageComplete: 0.5, iconType: .header)
      .padding()
  }
#endif
