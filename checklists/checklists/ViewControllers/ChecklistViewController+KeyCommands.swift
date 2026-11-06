//
//  ChecklistViewController+KeyCommands.swift
//  checklists
//

import UIKit

/// Hardware-keyboard shortcuts on ChecklistScreen. Each acts on the item being typed in, or presses
/// a button already on screen: there is no selected row outside typing (#404).
///
/// The list is rebuilt from the screen's state each time UIKit asks, which it does as first
/// responder changes, so a command that can't run is left out rather than shown dimmed. That also
/// keeps ⌘⌫'s "delete to line start" in the checklist's own name and notes, where no item is being
/// typed in.
extension ChecklistViewController {
  override var canBecomeFirstResponder: Bool {
    true
  }

  /// With no field typing, the controller itself takes first responder so ⌘N and Esc still reach
  /// it; a field that has the keyboard puts the controller in the chain anyway.
  func takeKeyCommandsIfIdle() {
    guard viewIfLoaded?.window != nil, !isEditingText, !isFirstResponder else { return }
    becomeFirstResponder()
  }

  override var keyCommands: [UIKeyCommand]? {
    // Esc carries no title: it presses the Done already on screen. Ahead of the text view, which
    // otherwise keeps it.
    let escape = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(escapeKeyPressed))
    escape.wantsPriorityOverSystemBehavior = true
    if isReordering {
      return [escape]
    }
    var commands = [Self.command("n", title: Self.newItemShortcutTitle, action: #selector(newItemKeyPressed))]
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
    if isEditingText {
      commands.append(escape)
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

  private func editingItemIndex() -> (ItemContentView, Int)? {
    guard
      let contentView = editingItemContentView,
      let item = contentView.item,
      let index = checklist.items.firstIndex(where: { $0.id == item.id })
    else { return nil }
    return (contentView, index)
  }

  @objc private func newItemKeyPressed() {
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
    guard let (_, index) = editingItemIndex() else { return }
    let count = checklist.items.count
    duplicateItem(at: index)
    guard checklist.items.count > count else { return } // The save failed and has said so.
    analytics.trackShortcut(.duplicateItem)
    startEditingRow(at: index + 1)
  }

  /// No confirmation, as with every other item delete. Typing moves to the row above first (the
  /// one below for the first row), so a keyboard user stays in the list.
  @objc private func deleteItemKeyPressed() {
    guard let (_, index) = editingItemIndex() else { return }
    analytics.trackShortcut(.deleteItem)
    let remaining = checklist.items.count - 1
    if let neighbour = DeletionFocus.editingNeighbourIndex(afterRemoving: index, remainingCount: remaining) {
      // Counted among the rows left; before the delete, a row below the deleted one is one further on.
      startEditingRow(at: neighbour >= index ? neighbour + 1 : neighbour)
    } else {
      view.endEditing(true)
    }
    deleteItem(at: index)
    postAccessibilityFeedback(focus: nil, announcement: Self.itemDeletedAnnouncement)
  }

  @objc private func escapeKeyPressed() {
    if isReordering {
      perform(.reorderDone)
    } else if isEditingText {
      perform(.editingDone)
    } else {
      return
    }
    analytics.trackShortcut(.done)
  }
}
