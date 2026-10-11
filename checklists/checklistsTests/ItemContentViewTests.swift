//
//  ItemContentViewTests.swift
//  checklistsTests
//
//  Created by Claude on 8/31/26.
//

@testable import checklists
import Testing
import UIKit

/// Covers `ItemContentView`'s keystroke state machine
/// (`textView(_:shouldChangeTextIn:replacementText:)`) and `refreshHeight()`'s notes-driven
/// expand/collapse state; full focus transfer isn't covered, since `becomeFirstResponder()` needs
/// a real window this test doesn't have.
@Suite("ItemContentView keystroke and height behaviour")
struct ItemContentViewTests {
  private final class RecordingDelegate: ItemContentViewDelegate {
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

  private func nameTextView(in contentView: ItemContentView) throws -> UITextView {
    try #require(findTextView(identifier: "itemNameTextView", in: contentView))
  }

  private func notesTextView(in contentView: ItemContentView) throws -> UITextView {
    try #require(findTextView(identifier: "itemNotesTextView", in: contentView))
  }

  private func activeHeightConstraint(on view: UIView) -> NSLayoutConstraint? {
    view.constraints.first { $0.isActive && $0.firstAttribute == .height && $0.firstItem === view }
  }

  // MARK: - Newline in the name field: insert next item

  @Test("a newline in the name field triggers insert-next-item and swallows the keystroke")
  func newlineInNameFieldTriggersInsertNextItemAndSwallowsKeystroke() throws {
    let contentView = ItemContentView()
    let delegate = RecordingDelegate()
    contentView.delegate = delegate
    let nameField = try nameTextView(in: contentView)

    let shouldChange = contentView.textView(nameField, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: "\n")

    #expect(!shouldChange)
    #expect(delegate.didReturnOnNameFieldCount == 1)
  }

  @Test("a newline in the notes field does not trigger insert-next-item")
  func newlineInNotesFieldDoesNotTriggerInsertNextItem() throws {
    // The newline shortcut is specific to the name field; the notes field should get an ordinary
    // newline character inserted (returns true, no delegate callback).
    let contentView = ItemContentView()
    let delegate = RecordingDelegate()
    contentView.delegate = delegate
    let notesField = try notesTextView(in: contentView)

    let shouldChange = contentView.textView(notesField, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: "\n")

    #expect(shouldChange)
    #expect(delegate.didReturnOnNameFieldCount == 0)
  }

  // MARK: - Backspace on an empty name field: merge-upward path

  @Test("backspacing on an empty name field triggers backspace-empty and swallows the keystroke")
  func backspaceOnEmptyNameFieldTriggersBackspaceEmptyAndSwallowsKeystroke() throws {
    let contentView = ItemContentView()
    let delegate = RecordingDelegate()
    contentView.delegate = delegate
    // Both fields start empty (no `item` assigned), matching the guard's requirement that the
    // notes field also be empty before treating this as "delete the whole item."
    let nameField = try nameTextView(in: contentView)

    let shouldChange = contentView.textView(nameField, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: "")

    #expect(!shouldChange)
    #expect(delegate.didBackspaceEmptyCount == 1)
  }

  @Test("backspacing on an empty name field with non-empty notes does not trigger backspace-empty")
  func backspaceOnEmptyNameFieldWithNonEmptyNotesDoesNotTriggerBackspaceEmpty() throws {
    // The guard requires BOTH fields to be empty; a non-empty notes field means there's still
    // something to lose, so backspacing on the (already-empty) name field should be a no-op here.
    let contentView = ItemContentView()
    contentView.item = Item(name: "", notes: "keep me")
    let delegate = RecordingDelegate()
    contentView.delegate = delegate
    let nameField = try nameTextView(in: contentView)

    let shouldChange = contentView.textView(nameField, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: "")

    #expect(shouldChange)
    #expect(delegate.didBackspaceEmptyCount == 0)
  }

  // MARK: - Backspace on an empty notes field: focus bounce back to the name field

  @Test("backspacing on an empty notes field swallows the keystroke")
  func backspaceOnEmptyNotesFieldSwallowsKeystroke() throws {
    // Full end-to-end focus transfer needs a real window (`becomeFirstResponder()` is a no-op
    // without one, per this file's header comment); what's testable headlessly is that the
    // keystroke is swallowed rather than actually deleting into an empty field.
    let contentView = ItemContentView()
    let delegate = RecordingDelegate()
    contentView.delegate = delegate
    let notesField = try notesTextView(in: contentView)

    let shouldChange = contentView.textView(notesField, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: "")

    #expect(!shouldChange)
    #expect(delegate.didBackspaceEmptyCount == 0, "The notes field's empty-backspace path bounces focus; it isn't the item-deletion path.")
  }

  // MARK: - Tapping between the two fields keeps the row in edit mode

  /// A touch inside either field must read as "still editing this item," so moving from the name
  /// field to the notes field doesn't collapse the row. `hitTest` hands back one of the text view's
  /// internal subviews rather than the text view itself, so the check has to be by containment.
  @Test("tapping inside the notes field does not finish editing")
  func tapInsideNotesFieldDoesNotFinishEditing() throws {
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

    #expect(delegate.didFinishEditingCount == 0, "Tapping into the notes field should keep the row in edit mode.")
  }

  /// The other half of the same rule: a touch that misses both fields still ends editing.
  @Test("tapping outside both fields finishes editing")
  func tapOutsideBothFieldsFinishesEditing() throws {
    let contentView = ItemContentView()
    contentView.item = Item(name: "Test")
    contentView.updateTextViewHeight(isExpanded: true)
    contentView.frame = CGRect(x: 0.0, y: 0.0, width: 340.0, height: 100.0)
    contentView.layoutIfNeeded()
    let delegate = RecordingDelegate()
    contentView.delegate = delegate
    let nameField = try nameTextView(in: contentView)

    _ = contentView.hitTest(CGPoint(x: 2.0, y: 2.0), with: nil) // On the checkbox, outside both fields.
    contentView.textViewDidEndEditing(nameField)

    #expect(delegate.didFinishEditingCount == 1, "Tapping away from both fields should end editing.")
  }

  // MARK: - refreshHeight() / expanded state driven by notes emptiness

  @Test("refreshHeight() expands the notes field when the item has notes")
  func refreshHeightExpandsWhenItemHasNotes() throws {
    let contentView = ItemContentView()
    contentView.item = Item(name: "Test", notes: "some notes")

    contentView.refreshHeight()

    let constraint = try #require(activeHeightConstraint(on: notesTextView(in: contentView)))
    #expect(constraint.relation == .greaterThanOrEqual)
    #expect(constraint.constant == 32.0)
  }

  @Test("refreshHeight() collapses the notes field when the item has no notes")
  func refreshHeightCollapsesWhenItemHasNoNotes() throws {
    let contentView = ItemContentView()
    contentView.item = Item(name: "Test") // notes is nil.

    contentView.refreshHeight()

    let constraint = try #require(activeHeightConstraint(on: notesTextView(in: contentView)))
    #expect(constraint.relation == .equal)
    #expect(constraint.constant == 0.0)
  }

  @Test("refreshHeight() collapses the notes field when the item's notes is an empty string")
  func refreshHeightCollapsesWhenItemNotesIsEmptyString() throws {
    let contentView = ItemContentView()
    contentView.item = Item(name: "Test", notes: "")

    contentView.refreshHeight()

    let constraint = try #require(activeHeightConstraint(on: notesTextView(in: contentView)))
    #expect(constraint.relation == .equal)
    #expect(constraint.constant == 0.0)
  }
}
