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

  func makeUIView(context _: Context) -> CircularPercentStatusIcon {
    let icon = CircularPercentStatusIcon(iconType: iconType)
    icon.percentageComplete = percentageComplete
    return icon
  }

  func updateUIView(_ uiView: CircularPercentStatusIcon, context _: Context) {
    uiView.percentageComplete = percentageComplete
  }

  func sizeThatFits(_: ProposedViewSize, uiView _: CircularPercentStatusIcon, context _: Context) -> CGSize? {
    // Matches CircularPercentStatusIcon.configureDimensions: 2 * radius per variant.
    // The radii themselves (10.0 / 12.0) are private to that class, so they're hardcoded
    // here rather than referenced — keep these in sync if configureDimensions changes.
    switch iconType {
    case .row:
      CGSize(width: 20, height: 20)
    case .header:
      CGSize(width: 24, height: 24)
    }
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

  #Preview("Header") {
    StatusIconView(percentageComplete: 0.5, iconType: .header)
      .padding()
  }
#endif
