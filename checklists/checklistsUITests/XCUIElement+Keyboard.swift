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

  /// Taps this field once it has settled, and fails unless it takes keyboard focus. For a tap that
  /// starts typing straight after a push or a sheet. The field must already be on screen: unlike a
  /// plain `tap()`, nothing here scrolls it into view.
  ///
  /// One tap, no retry: a field that has stopped moving and still ignores a tap is a bug a person
  /// would hit too. `offset` aims the tap within the field, as to put the caret after the last
  /// character.
  func tapForKeyboardFocus(at offset: CGVector? = nil, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(waitForSettledFrame(), "\(identifier) didn't appear and hold still to be tapped.", file: file, line: line)
    if let offset {
      coordinate(withNormalizedOffset: offset).tap()
    } else {
      tap()
    }
    XCTAssertTrue(waitForKeyboardFocus(), "\(identifier) didn't take keyboard focus.", file: file, line: line)
  }

  /// Waits for this element to exist, take taps, and hold still, as on a sheet done sliding up.
  /// A tap aims at the frame read just before it, so a tap on a field still moving can miss it and
  /// the field never takes focus. XCUITest's own wait for animations to end can give up under load.
  ///
  /// The timeout is generous because each poll reads the frame through accessibility, which takes
  /// seconds on a loaded CI runner; there 5s allowed too few polls to see the frame twice. A field
  /// that settles returns at once, so the margin costs nothing.
  private func waitForSettledFrame(timeout: TimeInterval = 15) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    var lastFrame: CGRect?
    while Date() < deadline {
      if exists, isHittable {
        let frame = frame
        if frame == lastFrame {
          return true
        }
        lastFrame = frame
      }
      Thread.sleep(forTimeInterval: 0.5)
    }
    return false
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
  /// screen sees rows the keyboard should be covering. Fails with the frame it last saw. The timeout
  /// is generous for the reason `waitForSettledFrame` gives.
  @discardableResult
  func waitForSoftwareKeyboard(
    _ message: String = "The software keyboard isn't on screen.",
    timeout: TimeInterval = 15,
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
