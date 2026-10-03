//
//  XCUIElement+Keyboard.swift
//  checklistsUITests
//

// The test scripts run the simulator headless, so nothing attaches a hardware keyboard to it.
// DeviceHub (`make sim-show`) can: its "Always simulate hardware keyboard" setting and per-device
// Keyboard menu decide it for a device it has open. Nobody has pinned down what else does; a
// suspect is the device's own `AutomaticMinimizationEnabled` / `HardwareKeyboardLastSeen` in
// `data/Library/Preferences/com.apple.keyboard.preferences.plist`, which survives reboots and
// nothing here resets. Don't read a green run as proof the keyboard was on screen.
//
// `SIM-KEYBOARD-FLAKE tests-failed` (from `scripts/check_keyboard_flake.py`) means something still
// depends on the keyboard and got past the gate check. #231 tracks retiring the tag once it stays
// quiet.

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
