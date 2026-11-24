import Foundation

/// The launch arguments every UI test starts the app with.
///
/// `-UITests1` always, plus `-UITestsNoAnimations` when the runner's environment has
/// `UITEST_ANIMATIONS=off` (CI only; see `TestAnimationsOverride` in the app).
enum UITestLaunch {
  static var arguments: [String] {
    if ProcessInfo.processInfo.environment["UITEST_ANIMATIONS"] == "off" {
      return ["-UITests1", "-UITestsNoAnimations"]
    }
    return ["-UITests1"]
  }
}
