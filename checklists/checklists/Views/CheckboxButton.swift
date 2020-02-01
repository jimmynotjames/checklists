//
//  CheckboxButton.swift
//  checklists
//
//  Created by Jimmy Ho on 5/14/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

class CheckboxButton: UIButton {
  convenience init() {
    self.init(frame: .zero)
  }

  override init(frame: CGRect) {
    super.init(frame: .zero)

    setImage(UIImage(named: "CheckboxUncheckedIcon"), for: .normal)
    setImage(UIImage(named: "CheckboxCheckedIcon"), for: .selected)

    contentEdgeInsets = UIEdgeInsets(top: 12.0, left: 12.0, bottom: 12.0, right: 12.0)

    setContentHuggingPriority(.required, for: .horizontal)
    setContentCompressionResistancePriority(.required, for: .horizontal)
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)

    [heightAnchor.constraint(equalToConstant: 44.0),
     widthAnchor.constraint(equalToConstant: 44.0)
     ].forEach { $0.isActive = true  }
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("This init() not supported.")
  }

  // Note: Must be called within write transaction.
  func setCheckboxState(with itemStatus: Item.Status) {
    switch itemStatus {
    case .checked:
      isSelected = true
      tintColor = Colors.inactiveText
    case .unchecked:
      isSelected = false
      tintColor = Colors.teal
    }
  }
}
