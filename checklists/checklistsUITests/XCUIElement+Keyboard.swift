//
//  XCUIElement+Keyboard.swift
//  checklistsUITests
//

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
