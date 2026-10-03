//
//  CheckboxButton.swift
//  checklists
//
//  Created by Jimmy Ho on 5/14/19.
//

import UIKit

class CheckboxButton: UIButton {
  /// The icon PDFs are 50pt; a configured button draws images at their own size, so they're
  /// redrawn at 24pt to keep the icon small inside the 48pt tap target.
  private static let iconSize = CGSize(width: 24.0, height: 24.0)
  private static let uncheckedImage = icon(named: "CheckboxUncheckedIcon")
  private static let checkedImage = icon(named: "CheckboxCheckedIcon")

  private static func icon(named name: String) -> UIImage? {
    guard let image = UIImage(named: name) else { return nil }
    return UIGraphicsImageRenderer(size: iconSize).image { _ in
      image.draw(in: CGRect(origin: .zero, size: iconSize))
    }.withRenderingMode(.alwaysTemplate)
  }

  convenience init() {
    self.init(frame: .zero)
  }

  override init(frame _: CGRect) {
    super.init(frame: .zero)

    accessibilityLabel = String(localized: "checkbox.accessibilityLabel", defaultValue: "Checkbox", comment: "VoiceOver label of the tick box on each checklist item row.")

    var configuration = UIButton.Configuration.plain()
    configuration.contentInsets = NSDirectionalEdgeInsets(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0)
    configuration.image = Self.uncheckedImage
    self.configuration = configuration
    // Off, so the plain style adds no selected background or pressed fade: the icon and tint are the state.
    automaticallyUpdatesConfiguration = false

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
