//
//  CLButton.swift
//  checklists
//
//  Created by Jimmy Ho on 7/25/19.
//

import UIKit

class CLButton: UIButton {
  override init(frame: CGRect) {
    super.init(frame: frame)
    configuration = .glass()
    // Not `.tintColor`: a configuration resolves its colors before the button has a window to
    // inherit a tint from, so the dynamic color lands on the label color instead of the accent.
    configuration?.baseForegroundColor = Colors.accent
    // The configuration keeps the color it first resolved, so re-resolve it when the appearance
    // changes.
    registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) { (button: Self, _) in
      button.configuration?.baseForegroundColor = Colors.accent.resolvedColor(with: button.traitCollection)
    }
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError()
  }
}
