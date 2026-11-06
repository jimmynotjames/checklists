//
//  ChecklistViewController+KeyCommands.swift
//  checklists
//

import UIKit

/// Hardware-keyboard shortcuts on ChecklistScreen. ⌘K, ⌘D, ⌘⌫ and Esc act on typing, so they live
/// here, in the chain of the field that has the keyboard. ⌘N and Reorder Items mode's Esc work with
/// nothing typed, so `ChecklistScreen` declares them on the SwiftUI side, which needs no first
/// responder.
///
/// The list is rebuilt from the screen's state each time UIKit asks, which it does as first
/// responder changes, so a command that can't run is left out rather than shown dimmed. That also
/// keeps ⌘⌫'s "delete to line start" in the checklist's own name and notes, where no item is being
/// typed in.
extension ChecklistViewController {
  override var keyCommands: [UIKeyCommand]? {
    guard !isReordering, isEditingText else { return [] }
    var commands: [UIKeyCommand] = []
    // Ahead of the text view, which otherwise keeps Esc; not while an input method is composing, where
    // Esc cancels the half-typed word.
    if !isComposingText {
      let escape = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(escapeKeyPressed))
      escape.wantsPriorityOverSystemBehavior = true
      commands.append(escape)
    }
    if editingItemContentView != nil {
      // ⌘⌫ goes ahead of the text view's own, which would delete only to the start of the line.
      // Backspace is "\u{8}"; `UIKeyCommand.inputDelete` is forward delete.
      let delete = Self.command("\u{8}", title: CommonStrings.delete, action: #selector(deleteItemKeyPressed))
      delete.wantsPriorityOverSystemBehavior = true
      commands += [
        Self.command("k", title: Self.toggleItemShortcutTitle, action: #selector(toggleItemKeyPressed)),
        Self.command("d", title: CommonStrings.duplicate, action: #selector(duplicateItemKeyPressed)),
        delete,
      ]
    }
    return commands
  }

  private static func command(_ input: String, title: String, action: Selector) -> UIKeyCommand {
    let command = UIKeyCommand(input: input, modifierFlags: .command, action: action)
    command.discoverabilityTitle = title
    return command
  }

  /// The row whose name or notes has the keyboard.
  private var editingItemContentView: ItemContentView? {
    (findEditingCell() as? ItemTableViewCell)?.itemContentView
  }

  private var editingItemIndex: Int? {
    guard let item = editingItemContentView?.item else { return nil }
    return checklist.items.firstIndex { $0.id == item.id }
  }

  /// ⌘N, from `ChecklistScreen`.
  func newItemKeyPressed() {
    guard !isReordering else { return }
    analytics.trackShortcut(.newItem)
    insertNewItem(becomeFirstResponder: true)
  }

  @objc private func toggleItemKeyPressed() {
    guard let contentView = editingItemContentView else { return }
    analytics.trackShortcut(.toggleItem)
    toggleItem(in: contentView)
  }

  /// The copy goes directly below, and typing moves into it, as Return's new row does.
  @objc private func duplicateItemKeyPressed() {
    guard let index = editingItemIndex else { return }
    let count = checklist.items.count
    duplicateItem(at: index)
    guard checklist.items.count > count else { return } // The save failed and has said so.
    analytics.trackShortcut(.duplicateItem)
    startEditingRow(at: index + 1)
  }

  /// No confirmation, as with every other item delete. Typing moves to the row above first (the
  /// one below for the first row), so a keyboard user stays in the list; VoiceOver goes with it.
  @objc private func deleteItemKeyPressed() {
    guard let index = editingItemIndex else { return }
    analytics.trackShortcut(.deleteItem)
    let neighbour = DeletionFocus.editingNeighbourIndex(afterRemoving: index, remainingCount: checklist.items.count - 1)
    if let neighbour {
      // Counted among the rows left; before the delete, a row below the deleted one is one further on.
      startEditingRow(at: neighbour >= index ? neighbour + 1 : neighbour)
    } else {
      view.endEditing(true)
    }
    deleteItem(at: index)
    postAccessibilityFeedback(focus: focusTargetAfterRemoval(neighbour: neighbour), announcement: Self.itemDeletedAnnouncement)
  }

  @objc private func escapeKeyPressed() {
    analytics.trackShortcut(.done)
    perform(.editingDone)
  }
}
