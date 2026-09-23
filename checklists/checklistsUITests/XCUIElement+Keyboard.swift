//
//  XCUIElement+Keyboard.swift
//  checklistsUITests
//

// No UI test taps a keyboard key: `make gate` fails on a new tap (`scripts/check_ui_test_keyboard.py`),
// because the Xcode recorder generates them.
//
// `scripts/_sim_sandbox.sh` still turns Simulator.app's "Connect Hardware Keyboard" off, for ad-hoc
// runs and anything that needs the keyboard on screen. The preference is per-UDID but owned by
// Simulator.app and read at boot, so it is written before a boot and `open -a Simulator` applies
// it. Under `SIMULATOR_UDID` none of this runs; fix it by hand:
//
//   UDID=$(cat .build/sim/device.udid)
//   python3 scripts/sim_keyboard_pref.py --disable "$UDID"
//   xcrun simctl shutdown "$UDID"; xcrun simctl boot "$UDID"; open -a Simulator
//
// The preference does not determine the outcome, and nobody has found what does: a control test
// that tapped `app.keys["delete"]` with `ConnectHardwareKeyboard = true` passed. Treat it as a
// hint, not a lever, and don't read a green run as proof it works. The next place to look is the
// device's own `AutomaticMinimizationEnabled` / `HardwareKeyboardLastSeen` in
// `data/Library/Preferences/com.apple.keyboard.preferences.plist`, which survives reboots and
// nothing here resets. `typeText` never queries the keyboard's accessibility elements, so the
// tests don't depend on which mechanism is real.
//
// Both paths print `SIM-KEYBOARD-FLAKE`: `guard-fired` when `_sim_sandbox.sh` cycles the
// simulator, `tests-failed` when `scripts/check_keyboard_flake.py` finds a run that failed on a
// keyboard key, meaning something still depends on the keyboard and got past the gate check.
// #231 tracks deleting this machinery once the tag stays quiet.

import XCTest

/// Keyboard input that does not depend on the software keyboard being on screen.
///
/// Tapping `app.keys["delete"]` or `app.buttons["Next:"]` needs the key rendered and hit-testable,
/// so those taps fail with `kAXErrorCannotComplete` on any simulator with a hardware keyboard
/// connected. `typeText` synthesizes an event against whatever holds keyboard focus instead.
///
/// Prefer calling these on the field rather than on `app`: typing into the element fails when it
/// never took focus, which is the check a key tap gave as a side effect.
extension XCUIElement {
  /// The return key, whatever `UIReturnKeyType` the focused field renders it as (`done`, `Next:`,
  /// `Return`).
  func pressReturnKey() {
    typeText(Self.returnEscape)
  }

  /// The delete key, `count` times.
  func pressDeleteKey(_ count: Int = 1) {
    typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count))
  }

  /// `XCUIKeyboardKey.return` is CR, but `ItemContentView.textView(_:shouldChangeTextIn:_:)`
  /// compares its replacement text against `"\n"`, so the escape that reaches the app has to be LF.
  private static let returnEscape = "\n"
}
