//
//  CheckboxButtonTests.swift
//  checklistsTests
//
//  Created by Claude on 10/10/26.
//

@testable import checklists
import Testing
import UIKit

/// The image checks matter because a mistyped SF Symbol name fails silently as nil.
@Suite("CheckboxButton size, images and state")
struct CheckboxButtonTests {
  @Test("keeps a 48pt square tap target with the glyph inside it")
  func tapTargetIs48Points() throws {
    // Pinned only by its leading and top edges, as `ItemContentView` pins it, so its size comes
    // from its own constraints. (`systemLayoutSizeFitting` on a button reports its content size.)
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
    let glyph = try #require(button.imageView)
    #expect(button.bounds.contains(glyph.frame))
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
