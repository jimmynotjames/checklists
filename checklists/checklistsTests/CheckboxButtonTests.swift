//
//  CheckboxButtonTests.swift
//  checklistsTests
//
//  Created by Claude on 10/10/26.
//

@testable import checklists
import Testing
import UIKit

/// Covers `CheckboxButton`'s tap-target size, its images (SF Symbols, whose names fail silently
/// as nil), and the state it exposes to VoiceOver and the UI tests.
@Suite("CheckboxButton size, images and state")
struct CheckboxButtonTests {
  @Test("keeps a 48pt square tap target, larger than its glyph")
  func tapTargetIs48Points() throws {
    // Laid out in a container, pinned only by its leading and top edges as `ItemContentView` pins
    // it, so its size comes from its own constraints. Glyph plus insets is not 48×48, so this is
    // what shows the 48pt constraints win over the required intrinsic size.
    // (`systemLayoutSizeFitting` on the button itself reports only its content size.)
    let button = CheckboxButton()
    button.translatesAutoresizingMaskIntoConstraints = false
    let container = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    container.addSubview(button)
    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      button.topAnchor.constraint(equalTo: container.topAnchor),
    ])
    container.layoutIfNeeded()
    #expect(button.frame.size == CGSize(width: 48.0, height: 48.0))
    let glyph = try #require(button.configuration?.image)
    #expect(glyph.size.width < 48.0)
    #expect(glyph.size.height < 48.0)
  }

  @Test("draws an image in both states")
  func imagesResolveInBothStates() {
    let button = CheckboxButton()
    button.setCheckboxState(with: .unchecked)
    let unchecked = button.configuration?.image
    button.setCheckboxState(with: .checked)
    let checked = button.configuration?.image
    #expect(unchecked != nil)
    #expect(checked != nil)
    #expect(unchecked != checked)
  }

  @Test("isSelected and the VoiceOver value follow the item status")
  func stateTracksStatus() {
    let button = CheckboxButton()
    button.setCheckboxState(with: .checked)
    #expect(button.isSelected)
    #expect(button.accessibilityValue == "Checked")
    button.setCheckboxState(with: .unchecked)
    #expect(!button.isSelected)
    #expect(button.accessibilityValue == "Unchecked")
    #expect(button.accessibilityLabel == "Checkbox")
  }
}
