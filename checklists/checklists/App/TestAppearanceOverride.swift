import SwiftUI

#if DEBUG
  /// Test-only hook to force light or dark appearance at launch.
  ///
  /// Per launch rather than through the simulator's own setting (`simctl ui … appearance`,
  /// `XCUIDevice.appearance`): those outlive a crashed run and would leave a shared simulator, and
  /// any screenshot captured on it later, in the wrong appearance.
  ///
  /// `preferredColorScheme` also sets the hosting window's interface style, so the UIKit checklist
  /// screen and the alerts it presents follow.
  ///
  /// Compiled out of Release. Even in DEBUG it applies no override unless the process is launched
  /// under test (`-UITests1` or `IS_TESTING`) with `FORCE_APPEARANCE=dark` or `light`.
  struct TestAppearanceOverride: ViewModifier {
    func body(content: Content) -> some View {
      content.preferredColorScheme(Self.forced)
    }

    /// The forced scheme, or `nil` when not under test or unset/unrecognized.
    static var forced: ColorScheme? {
      let env = ProcessInfo.processInfo.environment
      guard env["IS_TESTING"] != nil || CommandLine.arguments.contains("-UITests1") else { return nil }
      switch env["FORCE_APPEARANCE"] {
      case "dark": return .dark
      case "light": return .light
      default: return nil
      }
    }
  }
#endif
