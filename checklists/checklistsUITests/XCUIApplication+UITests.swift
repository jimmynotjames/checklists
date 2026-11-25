import XCTest

extension XCUIApplication {
  /// Sets what every UI test launches the app with: `-UITests1` plus `extraArguments`, and
  /// `FORCE_ANIMATIONS` passed through from the test runner's environment when it is set (CI only;
  /// see `TestAnimationsOverride` in the app). `keepsAnimations` opts a class out of that.
  func configureForUITests(extraArguments: [String] = [], keepsAnimations: Bool = false) {
    launchArguments = ["-UITests1"] + extraArguments
    if !keepsAnimations, let animations = ProcessInfo.processInfo.environment["FORCE_ANIMATIONS"] {
      launchEnvironment["FORCE_ANIMATIONS"] = animations
    }
  }
}
