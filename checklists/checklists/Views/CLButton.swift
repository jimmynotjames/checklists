//
//  CLButton.swift
//  checklists
//
//  Created by Jimmy Ho on 7/25/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

class CLButton: UIButton {
  private let normalColor: UIColor = UIColors.defaultBackground
  private let highlightedColor: UIColor = UIColors.teal

  override var isHighlighted: Bool {
    get {
      return super.isHighlighted
    }
    set {
      super.isHighlighted = newValue
      backgroundColor = newValue ? highlightedColor : normalColor
    }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    layer.borderWidth = 1.0
    layer.cornerRadius = 4.0
    layer.borderColor = highlightedColor.cgColor
    setTitleColor(highlightedColor, for: .normal)
    setTitleColor(normalColor, for: .highlighted)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }
}
