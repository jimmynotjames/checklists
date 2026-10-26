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

  /// Waits for this element to hold keyboard focus. A tap returns once the app goes idle, which can
  /// come before the field becomes first responder; typing then fails with "Neither element nor any
  /// descendant has keyboard focus".
  func waitForKeyboardFocus(timeout: TimeInterval = 10) -> Bool {
    let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: self)
    return XCTWaiter().wait(for: [focused], timeout: timeout) == .completed
  }

  /// `XCUIKeyboardKey.return` is CR, but `ItemContentView.textView(_:shouldChangeTextIn:_:)`
  /// compares its replacement text against `"\n"`, so the escape that reaches the app has to be LF.
  private static let returnEscape = "\n"
}

extension XCUIApplication {
  /// Waits for the software keyboard to be on screen and done sliding in, and returns it.
  ///
  /// `keyboards.firstMatch` existing isn't enough: iOS can park the keyboard just below the screen
  /// while the field keeps focus (`_keep_keyboard_on_screen` in `scripts/_sim_sandbox.sh`). A test
  /// that reads the keyboard's frame then measures against the wrong edge, and one that audits the
  /// screen sees rows the keyboard should be covering. Fails with the frame it last saw.
  @discardableResult
  func waitForSoftwareKeyboard(
    _ message: String = "The software keyboard isn't on screen.",
    timeout: TimeInterval = 5,
    file: StaticString = #filePath,
    line: UInt = #line,
  ) -> XCUIElement {
    let keyboard = keyboards.firstMatch
    let windowBottom = windows.firstMatch.frame.maxY
    let deadline = Date().addingTimeInterval(timeout)
    var lastFrame: CGRect?
    while Date() < deadline {
      if keyboard.exists {
        let frame = keyboard.frame
        // Unchanged since the last poll, so the slide-in has finished.
        if min(frame.maxY, windowBottom) - frame.minY >= Self.minimumKeyboardHeight, frame == lastFrame {
          return keyboard
        }
        lastFrame = frame
      }
      Thread.sleep(forTimeInterval: 0.25)
    }
    XCTFail("\(message) Last keyboard frame: \(lastFrame.map { "\($0)" } ?? "none").", file: file, line: line)
    return keyboard
  }

  /// A full iPhone keyboard stands about 300pt; a minimized one is a bar well under half that.
  private static let minimumKeyboardHeight: CGFloat = 150
}
