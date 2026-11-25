import SwiftUI
import UIKit

#if DEBUG
  /// Test-only hook to turn animations off at launch, for CI's UI tests.
  ///
  /// On CI's runners, some transitions (the Copy Checked Items sheet, edit mode, reorder mode)
  /// can't settle within XCUITest's 60-second "wait for app to idle", so each one stalls a test for
  /// a full minute. Locally they settle in seconds, so local runs keep their animations.
  ///
  /// The switch: ci.yml sets `TEST_RUNNER_FORCE_ANIMATIONS=off` on its UI-test jobs; xcodebuild
  /// hands it to the test runner as `FORCE_ANIMATIONS`, and `configureForUITests()` passes it on to
  /// the app's environment (AGENTS.md §CI covers reproducing it locally).
  ///
  /// Compiled out of Release. Even in DEBUG it does nothing unless the app is launched by a UI test
  /// (`-UITests1`) with `FORCE_ANIMATIONS=off`. Unlike `TestAppearanceOverride` it ignores
  /// `IS_TESTING`, so the unit tests' host app keeps its animations. Code that disables UIKit
  /// animations temporarily must scope it (`UIView.performWithoutAnimation`), not set them back to
  /// `true`.
  enum TestAnimationsOverride {
    static let isActive: Bool = CommandLine.arguments.contains("-UITests1")
      && ProcessInfo.processInfo.environment["FORCE_ANIMATIONS"] == "off"

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
