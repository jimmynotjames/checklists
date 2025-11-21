//
//  CLCircleButton.swift
//  checklists
//
//  Created by Jimmy Ho on 10/20/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

private let diameter: CGFloat = 60.0
private let insetRadius: CGFloat = 10.0

class CLCircleButtonLegacy: UIButton {

  static func addChecklistButton() -> CLCircleButtonLegacy {
    let button = CLCircleButtonLegacy(iconName: "AddChecklistIcon")
    button.accessibilityLabel = "Add new checklist."
    return button
  }

  convenience init(iconName: String) {
    self.init(frame: .zero)
    setImage(UIImage(named: iconName), for: .normal)
  }

  override init(frame: CGRect) {
    super.init(frame: frame)

    imageEdgeInsets = UIEdgeInsets(top: insetRadius, left: insetRadius, bottom: insetRadius, right: insetRadius)

    backgroundColor = CLUIColors.defaultBackground
    layer.borderColor = CLUIColors.defaultBackground.cgColor

    layer.shadowColor = UIColor.gray.cgColor
    layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
    layer.masksToBounds = false
    layer.shadowRadius = 3.0
    layer.shadowOpacity = 0.4
    layer.cornerRadius = diameter / 2.0

    // Better than superview setting because the corner radius is dependent on size, and doesn't need to be that robust.
    translatesAutoresizingMaskIntoConstraints = false
    heightAnchor.constraint(equalToConstant: diameter).isActive = true
    widthAnchor.constraint(equalToConstant: diameter).isActive = true
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }
}
