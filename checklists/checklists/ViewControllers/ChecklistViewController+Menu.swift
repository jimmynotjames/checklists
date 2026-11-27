//
//  ChecklistViewController+Menu.swift
//  checklists
//

import UIKit

/// What the navigation bar's buttons and the ⋯ menu do, the bar state they read
/// (`ChecklistBar`), and the dismissal Delete Checklist shares with the remote-deletion path. The
/// toolbar that draws them is `ChecklistScreen`'s.
extension ChecklistViewController {
  /// The ⋯ menu entries that act on the checked items.
  enum CheckedItemsMenuEntry {
    case copy
    case move
    case delete
  }

  /// Picks the menu's wording for this screen's mode and hands the bar its actions.
  func configureBar() {
    showsDiscardWording = isNewChecklist
    bar.isNewChecklist = isNewChecklist
    bar.perform = { [weak self] action in self?.perform(action) }
    bar.addItem = { [weak self] in self?.newItemKeyPressed() }
    updateBarMode(animated: false)
  }

  func perform(_ action: ChecklistBar.Action) {
    switch action {
    case .primary: primaryTapped()
    case .editingDone: editingDoneTapped()
    case .reorderDone: setEditing(false, animated: true)
    case .reorderItems: enterReorderMode()
    case .duplicate: duplicateChecklist()
    case .copyCheckedItems: checkedItemsEntryTapped(.copy)
    case .moveCheckedItems: checkedItemsEntryTapped(.move)
    case .exportPDF: exportPDF()
    case .deleteCheckedItems: checkedItemsEntryTapped(.delete)
    case .deleteChecklist: confirmDeleteChecklist()
    }
  }

  /// The create sheet's Done, or Reset on an existing checklist.
  private func primaryTapped() {
    if showsDiscardWording {
      doneButtonTapped()
    } else {
      resetButtonTapped()
    }
  }

  /// Typing in any field shows the editing Done at the outer edge, as Notes does, except on the
  /// create sheet, which keeps its own Done there (see `ChecklistBar.pinnedItem`). Reorder Items mode
  /// owns the bar while it is on.
  func updateBarMode(animated: Bool) {
    guard !isReordering else { return }
    bar.setMode(isEditingText ? .typing : .idle, animated: animated)
  }

  /// The editing Done, and Esc on any field.
  func editingDoneTapped() {
    view.endEditing(true)
    // On the create sheet only Esc gets here, and nothing in the bar changes, so VoiceOver stays put.
    guard !showsDiscardWording else { return }
    // The button VoiceOver was on is about to go; VoiceOver moves to what takes its place at the
    // outer edge.
    moveVoiceOverAfterBarSwap(to: .more)
  }

  /// Straight to the share sheet, with no sheet of options first: the screen behind the menu is
  /// what prints, so it is the preview, and anything to add, such as the client's details, goes in
  /// the checklist's notes.
  func exportPDF() {
    // Commits in-progress edits first, so the PDF shows what is on screen; see `duplicateChecklist`.
    view.endEditing(true)
    let snapshot = ChecklistPDFSnapshot.make(from: checklist, isRightToLeft: view.effectiveUserInterfaceLayoutDirection == .rightToLeft)
    let url: URL
    do {
      url = try makePDFExportFile(for: snapshot)
    } catch {
      // The description can name the file, and so the checklist, so only the domain and code are
      // public.
      let nsError = error as NSError
      AppLog.persistence.error(
        "Could not write the exported PDF: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public) \(nsError.localizedDescription, privacy: .private)",
      )
      onPDFExportFailed?()
      return
    }
    PDFShareSheet.present(url: url, from: self) { [weak self] completed in
      PDFExportFile.remove(url)
      guard completed, let self else { return }
      // Counts only: never anything from the checklist (analytics-spec.md §Deny-list).
      analytics.track(
        AnalyticsEvent.checklistPDFExported,
        properties: [
          AnalyticsProperty.itemsCount: snapshot.rows.count,
          AnalyticsProperty.checkedItemsCount: snapshot.rows.count(where: \.isChecked),
        ],
      )
    }
  }

  func makePDFExportFile(for snapshot: ChecklistPDFSnapshot) throws -> URL {
    let data = ChecklistPDFRenderer.render(snapshot)
    return try PDFExportFile.write(data, fileName: PDFFileName.make(title: snapshot.title, date: .now, timeZone: .current))
  }

  func enterReorderMode() {
    analytics.track(AnalyticsEvent.checklistReorderModeEntered)
    setEditing(true, animated: true)
  }

  /// Done in Reorder Items mode, ⋯ outside it: where VoiceOver goes when the mode swaps away the
  /// item it was on, which would leave it somewhere arbitrary.
  var barSwapFocusTarget: ChecklistBar.Item {
    isReordering ? .reorderDone : .more
  }

  /// See `core-docs/accessibility-spec.md` §Announcements and focus. `target` names the item
  /// outright; `nil` reads `barSwapFocusTarget` once the bar has relaid.
  func moveVoiceOverAfterBarSwap(to target: ChecklistBar.Item? = nil) {
    barSwapFocusTask?.cancel()
    guard let delay = barSwapFocusDelay else {
      bar.requestFocus(on: target ?? barSwapFocusTarget)
      return
    }
    barSwapFocusTask = Task { [weak self] in
      try? await Task.sleep(for: delay)
      // Not once the screen has gone, nor after a quicker toggle has taken over.
      guard !Task.isCancelled, let self, viewIfLoaded?.window != nil else { return }
      bar.requestFocus(on: target ?? barSwapFocusTarget)
    }
  }

  /// Internal so a test can invoke it: a SwiftUI menu button cannot be tapped from one.
  func checkedItemsEntryTapped(_ entry: CheckedItemsMenuEntry) {
    // Commits in-progress edits first; see `duplicateChecklist`.
    view.endEditing(true)
    // Live even with nothing ticked: hiding or dimming the entry would never teach that ticking
    // items is the selection, and the toast does.
    guard !checklist.checkedItems.isEmpty else {
      onNoCheckedItems?()
      return
    }
    switch entry {
    case .copy: transferCheckedItems(.copy)
    case .move: transferCheckedItems(.move)
    case .delete: confirmDeleteCheckedItems()
    }
  }

  func transferCheckedItems(_ mode: CheckedItemsTransferMode) {
    onRequestTransferCheckedItems?(checklist.id, mode)
  }

  /// Confirmed, unlike a single item's swipe: this can take most of a list at once, and nothing
  /// brings the items back. The count is in the message so the person sees how much is going.
  private func confirmDeleteCheckedItems() {
    let message = Self.deleteCheckedItemsConfirmationMessage(count: checklist.checkedItems.count)
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    // Cancel added first so it sits on the left, matching Delete Checklist's alert.
    alert.addAction(UIAlertAction(title: CommonStrings.cancel, style: .cancel))
    alert.addAction(UIAlertAction(title: CommonStrings.delete, style: .destructive) { [weak self] _ in
      self?.deleteCheckedItems()
    })
    present(alert, animated: true)
  }

  /// Unconfirmed on purpose: nothing is lost, and the sheet that follows offers Discard as the way
  /// back out.
  func duplicateChecklist() {
    // Commits a name or note still being typed into the *source*, so the copy carries what is on
    // screen rather than the last value that happened to be saved. Same first-responder hazard
    // `deleteChecklist` documents below, for the opposite reason.
    view.endEditing(true)
    guard let siblings = try? context.fetchChecklistsSorted() else {
      AppLog.persistence.error("Could not read the checklists to place a duplicate among.")
      return
    }
    guard let copy = try? context.duplicate(checklist: checklist, among: siblings) else {
      // Already logged and reported by `saveChanges`, and nothing was added; opening a sheet on a
      // checklist that does not exist would be the worse failure.
      return
    }
    analytics.track(
      AnalyticsEvent.checklistDuplicated,
      properties: [AnalyticsProperty.source: ChecklistDuplicationSource.menu.rawValue],
    )
    onRequestOpenDuplicate?(copy.id)
  }

  /// The existing-checklist wording matches the confirmation the checklists list puts behind a
  /// swipe, so deleting a checklist reads the same wherever it is started from; the create sheet
  /// gets its own copy for the same reason its menu entry does.
  private func confirmDeleteChecklist() {
    let message = showsDiscardWording ? Self.discardConfirmationMessage : CommonStrings.irreversibleConfirmation
    let confirmTitle = showsDiscardWording ? Self.discardActionTitle : CommonStrings.delete
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    // Cancel added first so it sits on the left, matching the list screen's alert.
    alert.addAction(UIAlertAction(title: CommonStrings.cancel, style: .cancel))
    alert.addAction(UIAlertAction(title: confirmTitle, style: .destructive) { [weak self] _ in
      self?.deleteChecklist()
    })
    present(alert, animated: true)
  }

  func deleteChecklist() {
    // Fired for a discard too: the store operation is identical, and "created then immediately
    // deleted" is itself a useful reading of checklist_created vs. checklist_deleted.
    analytics.track(AnalyticsEvent.checklistDeleted)
    // Clears the first responder while the record is still valid. Left to `viewWillDisappear`, the
    // field resigns during teardown instead and its delegate writes the committed text back into a
    // checklist that no longer exists.
    view.endEditing(true)
    // Leaving first and deleting second, with nothing suspending in between: the router has closed
    // the checklist before SwiftUI's next update, so `RootView`'s detail column is never re-resolved
    // against a checklist that has gone.
    requestDismissal()
    // The items go with it: the relationship's cascade delete rule handles that automatically.
    context.delete(checklist)
    context.saveChangesIgnoringFailure(operation: .delete)
  }

  /// Implements the contract on `onRequestDismiss`'s doc comment.
  func requestDismissal() {
    hasRequestedDismissal = true
    guard let onRequestDismiss else {
      assertionFailure("The host sets onRequestDismiss before the screen appears.")
      return
    }
    onRequestDismiss()
  }
}
