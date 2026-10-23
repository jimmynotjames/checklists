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
    didSet { applyDimensions() }
  }

  /// Multiplies the icon's size, ring and all. `StatusIconView` sets it from the text size so the
  /// ring keeps pace with a checklist's name; the header leaves it at 1.
  var scale: CGFloat = 1.0 {
    didSet {
      guard scale != oldValue else { return }
      applyDimensions()
    }
  }

  /// The icon's width and height for a type at a scale: twice its radius.
  static func diameter(for iconType: IconType, scale: CGFloat = 1.0) -> CGFloat {
    2 * baseRadius(for: iconType) * scale
  }

  private static func baseRadius(for iconType: IconType) -> CGFloat {
    switch iconType {
    case .row: 10.0
    case .header: 12.0
    }
  }

  var percentageComplete: CGFloat = 0.0 {
    didSet {
      setInnerCircle(percentageComplete: percentageComplete)
      accessibilityValue = Self.accessibilityValueText(forPercentageComplete: percentageComplete)
    }
  }

  /// The icon's whole VoiceOver announcement, as a value rather than a label — see `commonInit`.
  ///
  /// Static so a SwiftUI host can declare the same text: a `Button` row folds its content into one
  /// element whose value is whatever the merge picks up from the hosted UIView, so
  /// `ChecklistRowView` states it explicitly. Only the value — the grouping stays, because
  /// `ChecklistDetailUITestCase` and its subclasses address the icon and the notes label as elements
  /// inside the row.
  static func accessibilityValueText(forPercentageComplete percentageComplete: CGFloat) -> String {
    // Locale-aware percent: "18%" in English, "18 %" in French, "%18" in Turkish.
    let percent = Double(percentageComplete).formatted(.percent.precision(.fractionLength(0)))
    return String(
      localized: "checklist.progress.accessibilityValue",
      defaultValue: "Checklist \(percent) complete",
      comment: """
      VoiceOver value of the progress ring; the placeholder is an already-formatted percentage such \
      as 18%. Read it as "Checklist 18% complete": the share of items ticked so far, not a finished \
      list. Don't word it as "checklist completed" followed by the number.
      """,
    )
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
    configureDimensions()
    commonInit()
  }

  override func updateConstraints() {
    NSLayoutConstraint.deactivate(heightWidthAnchorConstraints)
    heightWidthAnchorConstraints = [heightAnchor.constraint(equalToConstant: 2 * radius), widthAnchor.constraint(equalToConstant: 2 * radius)]
    NSLayoutConstraint.activate(heightWidthAnchorConstraints)
    super.updateConstraints()
  }

  override init(frame _: CGRect) {
    fatalError()
  }

  required init?(coder aDecoder: NSCoder) {
    iconType = .header
    super.init(coder: aDecoder)
    configureDimensions()
    commonInit()
  }

  private func commonInit() {
    isAccessibilityElement = true
    // The percent is the whole announcement, so it lives in `accessibilityValue` and the label
    // stays nil: giving it a label too makes VoiceOver read the progress twice over.
    accessibilityLabel = nil
    // `percentageComplete`'s `didSet` does not run for the property's own default, so without this
    // an icon that is never assigned afterwards would announce nothing at all.
    accessibilityValue = Self.accessibilityValueText(forPercentageComplete: percentageComplete)

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

  private func configureDimensions() {
    radius = Self.baseRadius(for: iconType) * scale
    switch iconType {
    case .row:
      innerRadius = 7.5 * scale
      outerRingLineWidth = 0.5 * scale
    case .header:
      innerRadius = 9.5 * scale
      outerRingLineWidth = 1.0 * scale
    }
  }

  /// Re-derives everything sized from the radius after `iconType` or `scale` changes.
  private func applyDimensions() {
    configureDimensions()
    layer.borderWidth = outerRingLineWidth
    layer.cornerRadius = radius
    setInnerCircle(percentageComplete: percentageComplete)
    invalidateIntrinsicContentSize()
    setNeedsUpdateConstraints()
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
