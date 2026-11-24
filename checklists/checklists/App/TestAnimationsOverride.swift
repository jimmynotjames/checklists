import SwiftUI
import UIKit

#if DEBUG
  /// Test-only hook that turns animations off, for CI's UI tests.
  ///
  /// On CI's 3-vCPU runners, some transitions (the Copy Checked Items sheet, edit mode, reorder
  /// mode) can't settle within XCUITest's 60-second "wait for app to idle", so each one stalls a
  /// test for a full minute (issue #430). Locally they settle in seconds, and local runs keep their
  /// animations: only CI sets the switch (`TEST_RUNNER_UITEST_ANIMATIONS=off` in ci.yml, which the
  /// UI tests turn into `-UITestsNoAnimations`).
  ///
  /// Compiled out of Release. Even in DEBUG it does nothing unless launched with
  /// `-UITestsNoAnimations`.
  enum TestAnimationsOverride {
    static let isActive = CommandLine.arguments.contains("-UITestsNoAnimations")

    /// UIKit: view animations, presentations and table edit-mode changes become instant.
    static func applyToUIKit() {
      if isActive {
        UIView.setAnimationsEnabled(false)
      }
    }

    /// SwiftUI: `.animation` modifiers, `withAnimation` and sheet transitions under the root.
    struct Modifier: ViewModifier {
      func body(content: Content) -> some View {
        if TestAnimationsOverride.isActive {
          content.transaction { transaction in
            transaction.disablesAnimations = true
            transaction.animation = nil
          }
        } else {
          content
        }
      }
    }
  }
#endif
