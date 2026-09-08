//
//  CircularPercentStatusIcon.swift
//  checklists
//
//  Created by Jimmy Ho on 11/19/20.
//

import UIKit

class CircularPercentStatusIcon: UIView {
  enum IconType {
    /// The smaller icon shown beside a checklist's name in a list row.
    case row
    /// The larger icon shown in the checklist-detail screen's header.
    case header
  }

  var iconType: IconType {
    didSet {
      configureDimensions(iconType: iconType)
      setNeedsUpdateConstraints()
      setNeedsDisplay()
    }
  }

  var percentageComplete: CGFloat = 0.0 {
    didSet {
      setInnerCircle(percentageComplete: percentageComplete)
      accessibilityValue = String(format: "Checklist %.0f percent complete", percentageComplete * 100)
    }
  }

  private let color: CGColor = Colors.accent.cgColor
  private var radius: CGFloat!
  private var innerRadius: CGFloat!
  private var outerRingLineWidth: CGFloat!

  private var innerPercentCircleLayer: CAShapeLayer = .init()

  private var heightWidthAnchorConstraints: [NSLayoutConstraint] = []

  required init(iconType: IconType) {
    self.iconType = iconType
    super.init(frame: .zero)
    configureDimensions(iconType: iconType)
    commonInit()
  }

  override func updateConstraints() {
    NSLayoutConstraint.deactivate(heightWidthAnchorConstraints)
    NSLayoutConstraint.activate([heightAnchor.constraint(equalToConstant: 2 * radius), widthAnchor.constraint(equalToConstant: 2 * radius)])
    super.updateConstraints()
  }

  override init(frame _: CGRect) {
    fatalError()
  }

  required init?(coder aDecoder: NSCoder) {
    iconType = .header
    super.init(coder: aDecoder)
    configureDimensions(iconType: iconType)
    commonInit()
  }

  private func commonInit() {
    isAccessibilityElement = true
    accessibilityLabel = nil

    backgroundColor = .clear

    layer.borderWidth = outerRingLineWidth
    layer.borderColor = color
    layer.cornerRadius = radius

    // Better than superview setting because the corner radius is dependent on size, and doesn't need to be that robust.
    translatesAutoresizingMaskIntoConstraints = false

    setContentHuggingPriority(.required, for: .horizontal)
    setContentCompressionResistancePriority(.required, for: .horizontal)
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)

    layer.addSublayer(innerPercentCircleLayer)
  }

  private func configureDimensions(iconType: IconType) {
    switch iconType {
    case .row:
      radius = 10.0
      innerRadius = 7.5
      outerRingLineWidth = 0.5
    case .header:
      radius = 12.0
      innerRadius = 9.5
      outerRingLineWidth = 1.0
    }
  }

  private func setInnerCircle(percentageComplete: CGFloat) {
    innerPercentCircleLayer.removeAllAnimations()
    let center = CGPoint(x: radius, y: radius)
    let startAngle: CGFloat = -0.5 * .pi
    let endAngle: CGFloat = percentageComplete * (2 * .pi) - 0.5 * .pi // Percent * 360º - 90º offset
    let bezierPath = UIBezierPath()
    bezierPath.move(to: center)
    bezierPath.addArc(withCenter: center, radius: innerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
    innerPercentCircleLayer.path = bezierPath.cgPath
    innerPercentCircleLayer.fillColor = color
  }
}
