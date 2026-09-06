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
/// header icon — one implementation, one place the ring-drawing math and the
/// accessibility value ("Checklist X percent complete") can drift out of sync.
struct StatusIconView: UIViewRepresentable {
  var percentageComplete: CGFloat
  var iconType: CircularPercentStatusIcon.IconType = .tableViewCell

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
    case .tableViewCell:
      CGSize(width: 20, height: 20)
    case .header:
      CGSize(width: 24, height: 24)
    }
  }
}
