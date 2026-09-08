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
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError()
  }
}
