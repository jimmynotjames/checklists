//
//  CheckboxButton.swift
//  checklists
//
//  Created by Jimmy Ho on 5/14/19.
//

import UIKit

class CheckboxButton: UIButton {
  /// The 18pt is tuned by eye against the button's configuration, which draws a symbol larger
  /// than a bare `UIImageView` given the same configuration would.
  private static let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18.0, weight: .regular)
  private static let uncheckedImage = UIImage(systemName: "square", withConfiguration: symbolConfiguration)
  private static let checkedImage = UIImage(systemName: "checkmark.square.fill", withConfiguration: symbolConfiguration)

  convenience init() {
    self.init(frame: .zero)
  }

  override init(frame _: CGRect) {
    super.init(frame: .zero)

    accessibilityLabel = String(localized: "checkbox.accessibilityLabel", defaultValue: "Checkbox", comment: "VoiceOver label of the tick box on each checklist item row.")

    var configuration = UIButton.Configuration.plain()
    // Positions the glyph, not the tap target: the 48pt frame below is the tap target.
    configuration.contentInsets = NSDirectionalEdgeInsets(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0)
    configuration.image = Self.uncheckedImage
    self.configuration = configuration
    // Off, so the plain style adds no selected background or pressed fade: the icon and tint are the state.
    automaticallyUpdatesConfiguration = false

    // The only required size constraints. The symbol plus insets is not 48×48, so required content
    // hugging or compression resistance would contradict these and leave Auto Layout to break one.
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
      configuration?.image = Self.checkedImage
      tintColor = Colors.inactiveText
      accessibilityValue = String(localized: "checkbox.value.checked", defaultValue: "Checked", comment: "VoiceOver value of a ticked checklist item's checkbox.")
    case .unchecked:
      isSelected = false
      configuration?.image = Self.uncheckedImage
      tintColor = .tintColor
      accessibilityValue = String(localized: "checkbox.value.unchecked", defaultValue: "Unchecked", comment: "VoiceOver value of an unticked checklist item's checkbox.")
    }
  }
}
