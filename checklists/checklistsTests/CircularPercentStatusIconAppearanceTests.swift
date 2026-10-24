@testable import checklists
import Testing
import UIKit

@Suite("Progress ring appearance", .serialized)
struct CircularPercentStatusIconAppearanceTests {
  @Test("the header ring takes the dark accent when the screen turns dark")
  func followsAppearance() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", true), ("Eggs", false)]) { harness in
      let icon = harness.header.statusIcon
      let lightAccent = Colors.accent.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).cgColor
      let darkAccent = Colors.accent.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).cgColor

      harness.viewController.traitOverrides.userInterfaceStyle = .light
      harness.viewController.view.layoutIfNeeded()
      #expect(icon.layer.borderColor == lightAccent)

      harness.viewController.traitOverrides.userInterfaceStyle = .dark
      harness.viewController.view.layoutIfNeeded()
      #expect(icon.traitCollection.userInterfaceStyle == .dark)
      #expect(icon.layer.borderColor == darkAccent)
      let fill = try #require(icon.layer.sublayers?.compactMap { $0 as? CAShapeLayer }.first)
      #expect(fill.fillColor == darkAccent)
    }
  }
}
