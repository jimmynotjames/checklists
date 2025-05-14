//
//  RoundCheckboxButton.swift
//  checklists
//
//  Created by Jimmy Ho on 8/10/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

class RoundCheckboxButton: UIButton {
  convenience init() {
    self.init(frame: .zero)
  }

  override init(frame: CGRect) {
    super.init(frame: .zero)
    commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    tintColor = CLUIColors.teal
    setImage(UIImage(named: "RoundCheckboxUnchecked25x25"), for: .normal)
    setImage(UIImage(named: "RoundCheckboxChecked25x25"), for: .selected)

    setContentHuggingPriority(.required, for: .horizontal)
    setContentCompressionResistancePriority(.required, for: .horizontal)
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)

  }
}
