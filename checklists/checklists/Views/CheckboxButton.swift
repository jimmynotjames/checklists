//
//  CheckboxButton.swift
//  checklists
//
//  Created by Jimmy Ho on 5/14/19.
//

import UIKit

class CheckboxButton: UIButton {
  convenience init() {
    self.init(frame: .zero)
  }

  override init(frame _: CGRect) {
    super.init(frame: .zero)

    accessibilityLabel = String(localized: "checkbox.accessibilityLabel", defaultValue: "Checkbox", comment: "VoiceOver label of the tick box on each checklist item row.")

    setImage(UIImage(named: "CheckboxUncheckedIcon"), for: .normal)
    setImage(UIImage(named: "CheckboxCheckedIcon"), for: .selected)

    contentEdgeInsets = UIEdgeInsets(top: 12.0, left: 12.0, bottom: 12.0, right: 12.0)

    setContentHuggingPriority(.required, for: .horizontal)
    setContentCompressionResistancePriority(.required, for: .horizontal)
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)

    [heightAnchor.constraint(equalToConstant: 48.0),
     widthAnchor.constraint(equalToConstant: 48.0)].forEach { $0.isActive = true }
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("This init() not supported.")
  }

  /// Note: Only reflects the status on screen; saving it is the caller's job.
  func setCheckboxState(with itemStatus: Item.Status) {
    switch itemStatus {
    case .checked:
      isSelected = true
      tintColor = Colors.inactiveText
      accessibilityValue = String(localized: "checkbox.value.checked", defaultValue: "Checked", comment: "VoiceOver value of a ticked checklist item's checkbox.")
    case .unchecked:
      isSelected = false
      tintColor = .tintColor
      accessibilityValue = String(localized: "checkbox.value.unchecked", defaultValue: "Unchecked", comment: "VoiceOver value of an unticked checklist item's checkbox.")
    }
  }
}
