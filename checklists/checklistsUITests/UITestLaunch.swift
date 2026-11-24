import Foundation

/// The launch arguments every UI test starts the app with.
///
/// `-UITests1` always. `-UITestsNoAnimations` only when the test runner's environment has
/// `UITEST_ANIMATIONS=off`, which only CI sets (as `TEST_RUNNER_UITEST_ANIMATIONS`; xcodebuild
/// strips the prefix). Local runs keep their animations. See `TestAnimationsOverride` in the app.
enum UITestLaunch {
  static var arguments: [String] {
    if ProcessInfo.processInfo.environment["UITEST_ANIMATIONS"] == "off" {
      return ["-UITests1", "-UITestsNoAnimations"]
    }
    return ["-UITests1"]
  }
}
