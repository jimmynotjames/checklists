//
//  CircularPercentStatusIcon.swift
//  checklists
//
//  Created by Jimmy Ho on 11/20/24.
//  Copyright © 2024 Jimmy Ho. All rights reserved.
//

/*
 Features:
 Given a percentage, this view draws a circular pie segment to represent the percentage.
 The pie segement is drawn in a clockwise direction starting from the top of the circle.
 See Preview for examples.
 */

import SwiftUI


struct CircularPercentStatusIcon: View {
  enum IconType {
    case item
    case header
  }
  
  var iconType: IconType
  var percentageComplete: CGFloat // Value between 0.0 and 1.0
  
  // Computed properties for dimensions
  private var radius: CGFloat {
    switch iconType {
    case .item: return 10.0
    case .header: return 12.0
    }
  }
  
  private var innerRadius: CGFloat {
    switch iconType {
    case .item: return 7.5
    case .header: return 9.5
    }
  }
  
  private var outerRingLineWidth: CGFloat {
    switch iconType {
    case .item: return 0.5
    case .header: return 1.0
    }
  }
  
  private let color = CLColors.teal
  
  var body: some View {
    ZStack {
      // Outer ring
      Circle()
        .strokeBorder(color, lineWidth: outerRingLineWidth)
        .frame(width: radius * 2, height: radius * 2)

      // Inner percentage-filled circle
      CircleSegment(percentage: percentageComplete, radius: innerRadius)
        .fill(color)
    }
    .frame(width: radius * 2, height: radius * 2)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Checklist")
    .accessibilityValue("\(Int(percentageComplete * 100)) percent complete")
  }
}

struct CircleSegment: Shape {
  var percentage: CGFloat
  var radius: CGFloat
  
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let startAngle: CGFloat = -90.0 // Start at the top of the circle.
    let endAngle: CGFloat = startAngle + (percentage * 360.0) // Percentage in degrees
    path.move(to: center)
    path.addArc(
      center: center,
      radius: radius,
      startAngle: Angle(degrees: startAngle),
      endAngle: Angle(degrees: endAngle),
      clockwise: false
    )
    path.closeSubpath()
    return path
  }
}


#Preview {
  VStack {
    CircularPercentStatusIcon(iconType: .item, percentageComplete: 1.0)
    CircularPercentStatusIcon(iconType: .item, percentageComplete: 0.75)
    CircularPercentStatusIcon(iconType: .item, percentageComplete: 0.33)
    CircularPercentStatusIcon(iconType: .item, percentageComplete: 0.0)
    CircularPercentStatusIcon(iconType: .header, percentageComplete: 1.0)
    CircularPercentStatusIcon(iconType: .header, percentageComplete: 0.75)
    CircularPercentStatusIcon(iconType: .header, percentageComplete: 0.33)
    CircularPercentStatusIcon(iconType: .header, percentageComplete: 0.0)
  }
}
