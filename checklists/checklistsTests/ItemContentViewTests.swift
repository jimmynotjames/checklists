//
//  ItemContentViewTests.swift
//  checklistsTests
//
//  Created by Claude on 8/31/26.
//

@testable import checklists
import XCTest

/// Covers `ItemContentView`'s keystroke state machine
/// (`textView(_:shouldChangeTextIn:replacementText:)`) via a recording stub of
/// `ItemContentViewDelegate`, plus `refreshHeight()`'s expanded/collapsed state driven by notes
/// emptiness.
///
/// This is the plan's stretch item. What's covered: newline-in-name-field ("insert next item," and
/// the method returning `false` to swallow the keystroke), backspace-on-an-empty-name-field (the
/// merge-upward path), and `refreshHeight()`. What's NOT covered, and why: the notes-field
/// backspace-to-name-field "focus bounce" only verifies the swallowed-keystroke return value, not
/// that focus actually transfers — `becomeFirstResponder()` requires a real window/key-window to
/// succeed, which a headless unit test doesn't have (that's what the UI test suite's keyboard
/// interactions already cover end to end).
///
/// No Realm/DBManager involvement beyond creating unmanaged `Item` values, so this doesn't need the
/// in-memory-Realm save/restore pattern the persistence-touching test classes use. See the note on
/// `DataModelTests` for why this class is `nonisolated` at the type level with individual
/// `@MainActor` test methods.
nonisolated final class ItemContentViewTests: XCTestCase {
  /// Records every `ItemContentViewDelegate` callback it receives, for assertion.
  @MainActor private final class RecordingDelegate: ItemContentViewDelegate {
    private(set) var checkboxTappedCount = 0
    private(set) var nameFieldDidBeginEditingCount = 0
    private(set) var didFinishEditingCount = 0
    private(set) var heightUpdatedCount = 0
    private(set) var nameFieldUpdates: [String] = []
    private(set) var notesFieldUpdates: [String] = []
    private(set) var didReturnOnNameFieldCount = 0
    private(set) var didBackspaceEmptyCount = 0

    func itemContentViewCheckboxButtonTapped(_: ItemContentView) {
      checkboxTappedCount += 1
    }

    func itemContentViewNameFieldDidBeginEditing(_: ItemContentView) {
      nameFieldDidBeginEditingCount += 1
    }

    func itemContentViewDidFinishEditing(_: ItemContentView) {
      didFinishEditingCount += 1
    }

    func itemContentViewHeightUpdated(_: ItemContentView) {
      heightUpdatedCount += 1
    }

    func itemContentView(_: ItemContentView, nameFieldUpdatedWith name: String) {
      nameFieldUpdates.append(name)
    }

    func itemContentView(_: ItemContentView, notesFieldUpdatedWith notes: String) {
      notesFieldUpdates.append(notes)
    }

    func itemContentViewDidReturnOnNameField(_: ItemContentView) {
      didReturnOnNameFieldCount += 1
    }

    func itemContentViewDidBackspaceEmpty(_: ItemContentView) {
      didBackspaceEmptyCount += 1
    }
  }

  /// `nameTextView`/`notesTextView` are private; both are `CLTextView`s added directly to the view
  /// hierarchy with distinct `accessibilityIdentifier`s, so they're reachable this way.
  private func findTextView(identifier: String, in view: UIView) -> UITextView? {
    if let textView = view as? UITextView, textView.accessibilityIdentifier == identifier {
      return textView
    }
    for subview in view.subviews {
      if let found = findTextView(identifier: identifier, in: subview) {
        return found
      }
    }
    return nil
  }

  @MainActor private func nameTextView(in contentView: ItemContentView) throws -> UITextView {
    try XCTUnwrap(findTextView(identifier: "itemNameTextView", in: contentView))
  }

  @MainActor private func notesTextView(in contentView: ItemContentView) throws -> UITextView {
    try XCTUnwrap(findTextView(identifier: "itemNotesTextView", in: contentView))
  }

  @MainActor private func activeHeightConstraint(on view: UIView) -> NSLayoutConstraint? {
    view.constraints.first { $0.isActive && $0.firstAttribute == .height && $0.firstItem === view }
  }

  // MARK: - Newline in the name field: insert next item

  @MainActor func testNewlineInNameFieldTriggersInsertNextItemAndSwallowsKeystroke() throws {
    let contentView = ItemContentView()
    let delegate = RecordingDelegate()
    contentView.delegate = delegate
    let nameField = try nameTextView(in: contentView)

    let shouldChange = contentView.textView(nameField, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: "\n")

    XCTAssertFalse(shouldChange)
    XCTAssertEqual(delegate.didReturnOnNameFieldCount, 1)
  }

  @MainActor func testNewlineInNotesFieldDoesNotTriggerInsertNextItem() throws {
    // The newline shortcut is specific to the name field; the notes field should get an ordinary
    // newline character inserted (returns true, no delegate callback).
    let contentView = ItemContentView()
    let delegate = RecordingDelegate()
    contentView.delegate = delegate
    let notesField = try notesTextView(in: contentView)

    let shouldChange = contentView.textView(notesField, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: "\n")

    XCTAssertTrue(shouldChange)
    XCTAssertEqual(delegate.didReturnOnNameFieldCount, 0)
  }

  // MARK: - Backspace on an empty name field: merge-upward path

  @MainActor func testBackspaceOnEmptyNameFieldTriggersBackspaceEmptyAndSwallowsKeystroke() throws {
    let contentView = ItemContentView()
    let delegate = RecordingDelegate()
    contentView.delegate = delegate
    // Both fields start empty (no `item` assigned), matching the guard's requirement that the
    // notes field also be empty before treating this as "delete the whole item."
    let nameField = try nameTextView(in: contentView)

    let shouldChange = contentView.textView(nameField, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: "")

    XCTAssertFalse(shouldChange)
    XCTAssertEqual(delegate.didBackspaceEmptyCount, 1)
  }

  @MainActor func testBackspaceOnEmptyNameFieldWithNonEmptyNotesDoesNotTriggerBackspaceEmpty() throws {
    // The guard requires BOTH fields to be empty; a non-empty notes field means there's still
    // something to lose, so backspacing on the (already-empty) name field should be a no-op here.
    let contentView = ItemContentView()
    contentView.item = Item(name: "", notes: "keep me")
    let delegate = RecordingDelegate()
    contentView.delegate = delegate
    let nameField = try nameTextView(in: contentView)

    let shouldChange = contentView.textView(nameField, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: "")

    XCTAssertTrue(shouldChange)
    XCTAssertEqual(delegate.didBackspaceEmptyCount, 0)
  }

  // MARK: - Backspace on an empty notes field: focus bounce back to the name field

  @MainActor func testBackspaceOnEmptyNotesFieldSwallowsKeystroke() throws {
    // Full end-to-end focus transfer needs a real window (`becomeFirstResponder()` is a no-op
    // without one, per this file's header comment); what's testable headlessly is that the
    // keystroke is swallowed rather than actually deleting into an empty field.
    let contentView = ItemContentView()
    let delegate = RecordingDelegate()
    contentView.delegate = delegate
    let notesField = try notesTextView(in: contentView)

    let shouldChange = contentView.textView(notesField, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: "")

    XCTAssertFalse(shouldChange)
    XCTAssertEqual(delegate.didBackspaceEmptyCount, 0, "The notes field's empty-backspace path bounces focus; it isn't the item-deletion path.")
  }

  // MARK: - Tapping between the two fields keeps the row in edit mode

  /// A touch inside either field must read as "still editing this item," so moving from the name
  /// field to the notes field doesn't collapse the row. `hitTest` hands back one of the text view's
  /// internal subviews rather than the text view itself, so the check has to be by containment.
  @MainActor func testTapInsideNotesFieldDoesNotFinishEditing() throws {
    let contentView = ItemContentView()
    contentView.item = Item(name: "Test") // No notes, so a collapse here would be visible.
    contentView.updateTextViewHeight(isExpanded: true)
    contentView.frame = CGRect(x: 0.0, y: 0.0, width: 340.0, height: 100.0)
    contentView.layoutIfNeeded()
    let delegate = RecordingDelegate()
    contentView.delegate = delegate
    let notesField = try notesTextView(in: contentView)
    let nameField = try nameTextView(in: contentView)

    let pointInNotes = contentView.convert(CGPoint(x: notesField.bounds.midX, y: notesField.bounds.midY), from: notesField)
    _ = contentView.hitTest(pointInNotes, with: nil)
    contentView.textViewDidEndEditing(nameField) // The name field resigns as notes takes over.

    XCTAssertEqual(delegate.didFinishEditingCount, 0, "Tapping into the notes field should keep the row in edit mode.")
  }

  /// The other half of the same rule: a touch that misses both fields still ends editing.
  @MainActor func testTapOutsideBothFieldsFinishesEditing() throws {
    let contentView = ItemContentView()
    contentView.item = Item(name: "Test")
    contentView.updateTextViewHeight(isExpanded: true)
    contentView.frame = CGRect(x: 0.0, y: 0.0, width: 340.0, height: 100.0)
    contentView.layoutIfNeeded()
    let delegate = RecordingDelegate()
    contentView.delegate = delegate
    let nameField = try nameTextView(in: contentView)

    _ = contentView.hitTest(CGPoint(x: 2.0, y: 2.0), with: nil) // Above the fields, inside the view.
    contentView.textViewDidEndEditing(nameField)

    XCTAssertEqual(delegate.didFinishEditingCount, 1, "Tapping away from both fields should end editing.")
  }

  // MARK: - refreshHeight() / expanded state driven by notes emptiness

  @MainActor func testRefreshHeightExpandsWhenItemHasNotes() throws {
    let contentView = ItemContentView()
    contentView.item = Item(name: "Test", notes: "some notes")

    contentView.refreshHeight()

    let constraint = try XCTUnwrap(activeHeightConstraint(on: notesTextView(in: contentView)))
    XCTAssertEqual(constraint.relation, .greaterThanOrEqual)
    XCTAssertEqual(constraint.constant, 32.0)
  }

  @MainActor func testRefreshHeightCollapsesWhenItemHasNoNotes() throws {
    let contentView = ItemContentView()
    contentView.item = Item(name: "Test") // notes is nil.

    contentView.refreshHeight()

    let constraint = try XCTUnwrap(activeHeightConstraint(on: notesTextView(in: contentView)))
    XCTAssertEqual(constraint.relation, .equal)
    XCTAssertEqual(constraint.constant, 0.0)
  }

  @MainActor func testRefreshHeightCollapsesWhenItemNotesIsEmptyString() throws {
    let contentView = ItemContentView()
    contentView.item = Item(name: "Test", notes: "")

    contentView.refreshHeight()

    let constraint = try XCTUnwrap(activeHeightConstraint(on: notesTextView(in: contentView)))
    XCTAssertEqual(constraint.relation, .equal)
    XCTAssertEqual(constraint.constant, 0.0)
  }
}
