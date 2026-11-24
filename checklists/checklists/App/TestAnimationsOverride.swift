import SwiftUI
import UIKit

#if DEBUG
  /// Test-only hook that turns animations off, for CI's UI tests.
  ///
  /// On CI's runners, some transitions (the Copy Checked Items sheet, edit mode, reorder mode)
  /// can't settle within XCUITest's 60-second "wait for app to idle", so each one stalls a test for
  /// a full minute. Locally they settle in seconds, so local runs keep their animations.
  ///
  /// The switch: ci.yml sets `TEST_RUNNER_UITEST_ANIMATIONS=off` on its UI-test jobs; xcodebuild
  /// hands it to the test runner as `UITEST_ANIMATIONS`, and `UITestLaunch` then launches the app
  /// with `-UITestsNoAnimations`. Nothing local sets it; prefix `TEST_RUNNER_UITEST_ANIMATIONS=off`
  /// to a `make` test target to reproduce CI.
  ///
  /// Compiled out of Release. Even in DEBUG it does nothing unless launched with
  /// `-UITestsNoAnimations`. Code that disables UIKit animations temporarily must scope it
  /// (`UIView.performWithoutAnimation`), not set them back to `true`.
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
