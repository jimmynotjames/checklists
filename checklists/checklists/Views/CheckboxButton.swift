//
//  CheckboxButton.swift
//  checklists
//
//  Created by Jimmy Ho on 5/14/19.
//

import UIKit

class CheckboxButton: UIButton {
  /// The glyph and tap target at the default text size. The 18pt is tuned by eye against the
  /// button's configuration, which draws a symbol larger than a bare `UIImageView` given the same
  /// configuration would.
  private static let baseSymbolPointSize: CGFloat = 18.0
  private static let baseSide: CGFloat = 48.0
  /// Both grow with the item name's text style up to this factor, reached at xxxLarge: enough to stay
  /// in proportion with the text beside them, without crowding the name off a narrow row. They never
  /// shrink below their default, which keeps the tap target at least 48pt at the small sizes.
  private static let maximumScale: CGFloat = 1.25
  private static let uncheckedImage = UIImage(systemName: "square")
  private static let checkedImage = UIImage(systemName: "checkmark.square.fill")

  private lazy var widthConstraint = widthAnchor.constraint(equalToConstant: Self.baseSide)
  private lazy var heightConstraint = heightAnchor.constraint(equalToConstant: Self.baseSide)

  convenience init() {
    self.init(frame: .zero)
  }

  override init(frame _: CGRect) {
    super.init(frame: .zero)

    updateAccessibilityLabel()
    // The label carries the item's name, so UI tests need a handle that doesn't change with it.
    accessibilityIdentifier = "itemCheckbox"

    var configuration = UIButton.Configuration.plain()
    // Positions the glyph, not the tap target: the square frame below is the tap target.
    configuration.contentInsets = NSDirectionalEdgeInsets(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0)
    configuration.image = Self.uncheckedImage
    self.configuration = configuration
    // Off, so the plain style adds no selected background or pressed fade: the icon and tint are the state.
    automaticallyUpdatesConfiguration = false

    // The only required size constraints. The symbol plus insets is not the frame's size, so required
    // content hugging or compression resistance would contradict these and leave Auto Layout to break one.
    NSLayoutConstraint.activate([widthConstraint, heightConstraint])
    applyTextSize()

    registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (button: Self, _) in
      button.applyTextSize()
    }
  }

  private func applyTextSize() {
    let scale = min(
      max(UIFontMetrics(forTextStyle: .title2).scaledValue(for: 1.0, compatibleWith: traitCollection), 1.0),
      Self.maximumScale,
    )
    configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
      pointSize: Self.baseSymbolPointSize * scale,
      weight: .regular,
    )
    widthConstraint.constant = Self.baseSide * scale
    heightConstraint.constant = Self.baseSide * scale
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("This init() not supported.")
  }

  private static let blankNameStandIn = String(
    localized: "checkbox.accessibilityLabel",
    defaultValue: "Checkbox",
    comment: "Stands in for the item name in the checkbox's VoiceOver label when the item has no name, as in \"Unchecked, Checkbox\".",
  )

  private var itemName = ""

  /// Names the item the checkbox ticks, so VoiceOver doesn't read the same "Checkbox" on every row.
  func setItemName(_ name: String?) {
    itemName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    updateAccessibilityLabel()
  }

  /// The status leads and the name follows, so on a long name a listener hears the status and can
  /// move on. That puts state in the label, against the spec's label-vs-value convention; see
  /// `core-docs/accessibility-spec.md` §Label vs. value.
  private func updateAccessibilityLabel() {
    let name = itemName.isEmpty ? Self.blankNameStandIn : itemName
    accessibilityLabel = isSelected
      ? String(
        localized: "checkbox.accessibilityLabel.checked",
        defaultValue: "Checked, \(name)",
        comment: "VoiceOver label of a ticked checklist item's checkbox. The placeholder is the item's name. Keep the status first, so a listener hears it before a long name.",
      )
      : String(
        localized: "checkbox.accessibilityLabel.unchecked",
        defaultValue: "Unchecked, \(name)",
        comment: "VoiceOver label of an unticked checklist item's checkbox. The placeholder is the item's name. Keep the status first, so a listener hears it before a long name.",
      )
  }

  /// Note: Only reflects the status on screen; saving it is the caller's job.
  func setCheckboxState(with itemStatus: Item.Status) {
    switch itemStatus {
    case .checked:
      isSelected = true
      configuration?.image = Self.checkedImage
      tintColor = Colors.inactiveText
    case .unchecked:
      isSelected = false
      configuration?.image = Self.uncheckedImage
      tintColor = .tintColor
    }
    updateAccessibilityLabel()
  }
}
