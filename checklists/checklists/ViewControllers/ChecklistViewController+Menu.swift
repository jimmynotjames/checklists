//
//  ChecklistViewController+Menu.swift
//  checklists
//

import UIKit

/// The trailing navigation items, the overflow menu, the actions behind it, and the dismissal
/// the destructive one shares with the remote-deletion path.
///
/// `duplicateChecklist` and `deleteChecklist` are internal so a test can invoke them: a `UIAction`
/// handler cannot be fired directly.
extension ChecklistViewController {
  /// Picks the menu's wording for this screen's mode and builds the trailing bar items. The create
  /// sheet gets Done, an existing checklist gets Reset; both get the overflow menu at the outer edge.
  func configureNavigationBar() {
    showsDiscardWording = isNewChecklist
    let moreItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: makeMoreMenu())
    // Held on to so the menu can be rebuilt while it is on screen; see `refreshMoreMenu`.
    moreBarButtonItem = moreItem
    moreItem.accessibilityLabel = Self.moreMenuAccessibilityLabel
    // Locale-invariant handle for UI tests; the label above is what VoiceOver reads.
    moreItem.accessibilityIdentifier = "checklist.more"
    // iOS 26 renders bar buttons in `labelColor` unless the item itself carries a tint.
    moreItem.tintColor = .tintColor

    let primaryItem = if isNewChecklist {
      // The create sheet already inserted and saved a real row before this screen appeared
      // (ChecklistsView.addChecklist), so it needs its own way out besides Done: the menu doubles
      // as "cancel creation" here, worded as a discard rather than a delete.
      UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
    } else {
      // Reset keeps the bar slot: in an app built around rerunning a list it is a per-run action,
      // while deleting the list is a once-ever one that can afford to sit a tap deeper.
      UIBarButtonItem(title: Self.resetButtonTitle, style: .plain, target: self, action: #selector(resetButtonTapped))
    }
    primaryItem.tintColor = .tintColor
    // Trailing-first: the menu sits at the outer edge, Done or Reset next to the title.
    navigationItem.rightBarButtonItems = [moreItem, primaryItem]
  }

  func makeMoreMenu() -> UIMenu {
    let title = showsDiscardWording ? Self.discardChecklistMenuTitle : Self.deleteChecklistMenuTitle
    // `.destructive` is what turns the row red, and it is the only colour this menu carries.
    let deleteAction = UIAction(title: title, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
      self?.confirmDeleteChecklist()
    }
    // Nothing on the create sheet's checklist has been kept yet — copying a draft nobody has
    // decided to keep is not an action that means anything.
    guard !showsDiscardWording else { return UIMenu(children: [deleteAction]) }

    let duplicateAction = UIAction(title: Self.duplicateChecklistMenuTitle, image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in
      self?.duplicateChecklist()
    }
    // Inline sections, so the destructive entry keeps a gap above it and a thumb reaching for
    // Duplicate cannot land on Delete.
    return UIMenu(children: [
      UIMenu(options: .displayInline, children: [duplicateAction, copyCheckedItemsElement]),
      UIMenu(options: .displayInline, children: [deleteAction]),
    ])
  }

  /// The copy entry, and the notice explaining why a tap did nothing.
  ///
  /// The entry is always present and always live, even with nothing ticked: hiding or dimming it
  /// would never teach that ticking items *is* the selection, and the notice does. Deferred so it
  /// reads the checked items when the menu opens, rather than rebuilding the menu on every
  /// check-off, Reset and remote merge.
  private var copyCheckedItemsElement: UIDeferredMenuElement {
    // `uncached`, so the provider runs each time the menu opens rather than once per menu.
    UIDeferredMenuElement.uncached { [weak self] completion in
      guard let self else {
        completion([])
        return
      }
      let hasCheckedItems = !checklist.checkedItems.isEmpty
      let action = UIAction(
        title: Self.copyCheckedItemsMenuTitle,
        // Distinct from Duplicate's `plus.square.on.square` directly above it: these two sit
        // adjacent and a shared glyph would make one read as the other.
        image: UIImage(systemName: "doc.on.doc"),
        // Held open only in the case that has something to say in place. With something to copy,
        // the tap opens the picker and the menu should get out of the way as any other entry does.
        attributes: hasCheckedItems ? [] : .keepsMenuPresented
      ) { [weak self] _ in
        self?.copyCheckedItems()
      }
      guard !hasCheckedItems, showsNoItemsCheckedNotice else {
        completion([action])
        return
      }
      // A disabled action is the closest a `UIMenu` comes to a caption: it draws as a plain row
      // rather than as something to press, which is what this is.
      let notice = UIAction(title: Self.noItemsCheckedNotice, attributes: .disabled) { _ in }
      completion([action, notice])
    }
  }

  /// How long "No checked items." stays up: the same dwell a toast gets, copied rather than read
  /// from `ToastPresenter`, whose dwell is an initializer parameter.
  private static let noItemsCheckedNoticeDuration: Duration = .seconds(2)

  func copyCheckedItems() {
    // Commits in-progress edits first; see `duplicateChecklist`.
    view.endEditing(true)
    guard !checklist.checkedItems.isEmpty else {
      showNoItemsCheckedNotice()
      return
    }
    noItemsCheckedNoticeDismissal?.cancel()
    showsNoItemsCheckedNotice = false
    onRequestCopyCheckedItems?(checklist.id)
  }

  /// Puts "No checked items." under the copy entry and takes it away again a moment later.
  ///
  /// Timed like a toast because the menu it lives in offers nothing else to retire it: it is not
  /// a row anyone can dismiss, and a bar-button menu does not report being closed. Tapping the
  /// entry again while it is up restarts the dwell.
  private func showNoItemsCheckedNotice() {
    noItemsCheckedNoticeDismissal?.cancel()
    showsNoItemsCheckedNotice = true
    refreshMoreMenu()
    noItemsCheckedNoticeDismissal = Task { [weak self] in
      try? await Task.sleep(for: Self.noItemsCheckedNoticeDuration)
      guard !Task.isCancelled, let self, showsNoItemsCheckedNotice else { return }
      showsNoItemsCheckedNotice = false
      refreshMoreMenu()
    }
  }

  /// Rebuilds the overflow menu in place. Reassigning the bar item's menu is what makes one that
  /// is already on screen pick up a change; `.keepsMenuPresented` is what left it there to update.
  private func refreshMoreMenu() {
    moreBarButtonItem?.menu = makeMoreMenu()
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
      properties: [AnalyticsProperty.source: ChecklistDuplicationSource.menu.rawValue]
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
    // Leaving first and deleting second, with nothing suspending in between: the route is off the
    // router's path before SwiftUI's next update, so the push destination is never re-resolved
    // against a checklist that has gone.
    requestDismissal()
    // The items go with it: the relationship's cascade delete rule handles that automatically.
    context.delete(checklist)
    context.saveChangesIgnoringFailure(operation: .delete)
  }

  /// Implements the contract on `onRequestDismiss`'s doc comment; also the fallback for the
  /// pure-UIKit case that leaves it unset.
  func requestDismissal() {
    if let onRequestDismiss {
      onRequestDismiss()
    } else if let navigationController, navigationController.viewControllers.count > 1 {
      navigationController.popViewController(animated: true)
    } else {
      dismiss(animated: true)
    }
  }
}
