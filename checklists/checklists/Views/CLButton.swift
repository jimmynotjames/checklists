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
    configuration?.baseForegroundColor = Colors.teal
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError()
  }
}
