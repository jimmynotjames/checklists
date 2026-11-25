import XCTest

extension XCUIApplication {
  /// Sets what every UI test launches the app with: `-UITests1` plus `extraArguments`, and
  /// `FORCE_ANIMATIONS` passed through from the test runner's environment when it is set (CI only;
  /// see `TestAnimationsOverride` in the app).
  func configureForUITests(extraArguments: [String] = []) {
    launchArguments = ["-UITests1"] + extraArguments
    if let animations = ProcessInfo.processInfo.environment["FORCE_ANIMATIONS"] {
      launchEnvironment["FORCE_ANIMATIONS"] = animations
    }
  }
}
