//
//  ChecklistViewController+Menu.swift
//  checklists
//

import UIKit

/// The trailing navigation items, the overflow menu, the actions behind it, and the dismissal
/// Delete Checklist shares with the remote-deletion path.
///
/// `enterReorderMode`, `duplicateChecklist`, `transferCheckedItems(_:)`, `exportPDF`,
/// `makePDFExportFile` and `deleteChecklist` are internal so a test can invoke them: a `UIAction`
/// handler cannot be fired directly.
extension ChecklistViewController {
  /// The overflow-menu entries that act on the checked items, each of which can show "No checked
  /// items." under itself.
  enum CheckedItemsMenuEntry {
    case copy
    case move
    case delete
  }

  /// Picks the menu's wording for this screen's mode and builds the trailing bar items. The create
  /// sheet gets Done pinned at the outer edge, beyond the overflow menu, as a sheet's confirming
  /// action sits; an existing checklist gets Reset on the title side of the menu.
  func configureNavigationBar() {
    showsDiscardWording = isNewChecklist
    let moreItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: makeMoreMenu())
    // Held on to so the menu can be rebuilt while it is on screen; see `refreshMoreMenu`.
    moreBarButtonItem = moreItem
    moreItem.accessibilityLabel = CommonStrings.more
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
      // while deleting the list is a once-ever one that can afford to sit a tap deeper. An icon, so
      // on iPhone Duo it moves into the vertical bar with the rest; the title is what VoiceOver
      // reads and what the Large Content Viewer and an overflow menu show.
      UIBarButtonItem(
        title: Self.resetButtonTitle,
        image: UIImage(systemName: "arrow.counterclockwise"),
        target: self,
        action: #selector(resetButtonTapped),
      )
    }
    primaryItem.tintColor = .tintColor
    // Locale-invariant handles for UI tests; the create sheet's Done reads "Done", as the editing
    // Done does.
    primaryItem.accessibilityIdentifier = isNewChecklist ? "checklist.done" : "checklist.reset"
    primaryBarButtonItem = primaryItem

    // In the bar, not above the keyboard: on iOS 26 a keyboard toolbar spans the full width and
    // swallows taps on the rows behind its clear glass.
    let editingDoneItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(editingDoneTapped))
    editingDoneItem.tintColor = .tintColor
    editingDoneItem.accessibilityIdentifier = "checklist.editingDone"
    // Its own pill, as Notes draws it, rather than one shared with the menu.
    editingDoneItem.sharesBackground = false
    editingDoneBarButtonItem = editingDoneItem

    updateEditingDoneBarButtonItem(animated: false)
  }

  /// While a field is being typed into, pins the editing Done at the outer edge and leaves the rest
  /// where it was, as Notes does. On the create sheet it stands in for the sheet's own Done, which
  /// is pinned there otherwise. Reorder Items mode owns the whole bar while it is on, and puts back
  /// what it found.
  func updateEditingDoneBarButtonItem(animated: Bool) {
    guard !isReordering, let moreBarButtonItem, let primaryBarButtonItem, let editingDoneBarButtonItem else { return }
    // Trailing-first: index 0 is the outer edge, next to the pinned item.
    let items: [UIBarButtonItem] = showsDiscardWording ? [moreBarButtonItem] : [moreBarButtonItem, primaryBarButtonItem]
    pinnedTrailingItem = if isEditingText {
      editingDoneBarButtonItem
    } else {
      showsDiscardWording ? primaryBarButtonItem : nil
    }
    let current = navigationItem.rightBarButtonItems ?? []
    if !current.elementsEqual(items, by: ===) {
      navigationItem.setRightBarButtonItems(items, animated: animated)
    }
    mirrorBarToHost(animated: animated)
  }

  /// The one item in the navigation item's pinned trailing group: past ⋯ at the outer edge of a
  /// top bar, and at the top of iPhone Duo's vertical bar, under Back, where the overflow never
  /// takes it. Holds the screen's Done of the moment: the typing Done, the create sheet's, or Reorder
  /// Items mode's.
  var pinnedTrailingItem: UIBarButtonItem? {
    get { navigationItem.pinnedTrailingGroup?.barButtonItems.first }
    set {
      guard newValue !== pinnedTrailingItem else { return }
      navigationItem.pinnedTrailingGroup = newValue.map { UIBarButtonItemGroup(barButtonItems: [$0], representativeItem: nil) }
    }
  }

  @objc func editingDoneTapped() {
    view.endEditing(true)
    // The button VoiceOver was on is about to go; VoiceOver moves to what takes its place at the
    // outer edge: the create sheet's own Done, or ⋯.
    moveVoiceOverAfterBarSwap(to: showsDiscardWording ? primaryBarButtonItem : moreBarButtonItem)
  }

  func makeMoreMenu() -> UIMenu {
    let title = showsDiscardWording ? Self.discardChecklistMenuTitle : Self.deleteChecklistMenuTitle
    // `.destructive` is what turns the row red, and it is the only colour this menu carries.
    let deleteAction = UIAction(title: title, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
      self?.confirmDeleteChecklist()
    }
    // On the create sheet too: people often put items in order right after typing a batch of them.
    let reorderSection = UIMenu(options: .displayInline, children: [reorderItemsAction])
    // Nothing on the create sheet's checklist has been kept yet — copying, moving, exporting or
    // pruning a draft nobody has decided to keep is not an action that means anything.
    guard !showsDiscardWording else {
      return UIMenu(children: [reorderSection, UIMenu(options: .displayInline, children: [deleteAction])])
    }

    let duplicateAction = UIAction(title: Self.duplicateChecklistMenuTitle, image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in
      self?.duplicateChecklist()
    }
    // Inline sections, so the destructive entries keep a gap above them and a thumb reaching for
    // Move cannot land on a Delete. Export gets a section of its own: the three above it move
    // things between checklists inside the app, while it sends something out of the app.
    return UIMenu(children: [
      reorderSection,
      UIMenu(options: .displayInline, children: [
        duplicateAction,
        checkedItemsElement(for: .copy),
        checkedItemsElement(for: .move),
      ]),
      UIMenu(options: .displayInline, children: [exportPDFAction]),
      UIMenu(options: .displayInline, children: [checkedItemsElement(for: .delete), deleteAction]),
    ])
  }

  /// Always live, even with nothing checked or no items: a PDF showing nothing checked is still a
  /// valid record.
  private var exportPDFAction: UIAction {
    let action = UIAction(title: Self.exportPDFMenuTitle, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
      self?.exportPDF()
    }
    // Locale-invariant handle for UI tests.
    action.accessibilityIdentifier = "checklist.menu.exportPDF"
    return action
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
    PDFShareSheet.present(url: url, from: self, sourceItem: moreBarButtonItem) { [weak self] completed in
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

  private var reorderItemsAction: UIAction {
    let action = UIAction(title: Self.reorderItemsMenuTitle, image: UIImage(systemName: "arrow.up.arrow.down")) { [weak self] _ in
      self?.enterReorderMode()
    }
    // Locale-invariant handle for UI tests and the localized screenshot capture.
    action.accessibilityIdentifier = "checklist.menu.reorderItems"
    return action
  }

  func enterReorderMode() {
    analytics.track(AnalyticsEvent.checklistReorderModeEntered)
    setEditing(true, animated: true)
  }

  /// Clears the bar down to Done, as ChecklistsView's Edit mode does: one obvious way out, and no
  /// second Done beside the create sheet's own. The back button goes too, and its edge swipe with it;
  /// the VoiceOver escape gesture still leaves the mode.
  func applyReorderModeToNavigationBar(_ reordering: Bool, animated: Bool) {
    if reordering {
      savedRightBarButtonItems = navigationItem.rightBarButtonItems
      savedLeftBarButtonItem = navigationItem.leftBarButtonItem
      savedPinnedTrailingItem = pinnedTrailingItem
      // The same checkmark as the screen's other Dones, pinned where they sit.
      let doneItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(reorderDoneTapped))
      doneItem.tintColor = .tintColor
      doneItem.accessibilityIdentifier = "checklist.reorderDone"
      navigationItem.setLeftBarButton(nil, animated: animated)
      navigationItem.setHidesBackButton(true, animated: animated)
      navigationItem.setRightBarButtonItems(nil, animated: animated)
      pinnedTrailingItem = doneItem
    } else {
      navigationItem.setLeftBarButton(savedLeftBarButtonItem, animated: animated)
      navigationItem.setHidesBackButton(false, animated: animated)
      navigationItem.setRightBarButtonItems(savedRightBarButtonItems, animated: animated)
      pinnedTrailingItem = savedPinnedTrailingItem
      savedRightBarButtonItems = nil
      savedLeftBarButtonItem = nil
      savedPinnedTrailingItem = nil
    }
    mirrorBarToHost(animated: animated)
  }

  @objc private func reorderDoneTapped() {
    setEditing(false, animated: true)
  }

  /// Done in Reorder Items mode, ⋯ outside it: where VoiceOver goes when the mode swaps away the
  /// item it was on, which would leave it somewhere arbitrary.
  var barSwapFocusTarget: UIBarButtonItem? {
    isReordering ? pinnedTrailingItem : moreBarButtonItem
  }

  /// Posted with the bar item itself; see `core-docs/accessibility-spec.md` §Announcements and focus.
  /// `target` names the item outright; `nil` reads `barSwapFocusTarget` once the bar has relaid.
  func moveVoiceOverAfterBarSwap(to target: UIBarButtonItem? = nil) {
    barSwapFocusTask?.cancel()
    guard let delay = barSwapFocusDelay else {
      postAccessibilityFeedback(focus: target ?? barSwapFocusTarget, announcement: nil)
      return
    }
    barSwapFocusTask = Task { [weak self] in
      try? await Task.sleep(for: delay)
      // Not once the screen has gone, nor after a quicker toggle has taken over.
      guard !Task.isCancelled, let self, viewIfLoaded?.window != nil else { return }
      postAccessibilityFeedback(focus: target ?? barSwapFocusTarget, announcement: nil)
    }
  }

  /// A checked-items entry, and the notice explaining why a tap on it did nothing.
  ///
  /// Each entry is always present and always live, even with nothing ticked: hiding or dimming it
  /// would never teach that ticking items *is* the selection, and the notice does. Deferred so it
  /// reads the checked items when the menu opens, rather than rebuilding the menu on every
  /// check-off, Reset and remote merge.
  private func checkedItemsElement(for entry: CheckedItemsMenuEntry) -> UIDeferredMenuElement {
    // `uncached`, so the provider runs each time the menu opens rather than once per menu.
    UIDeferredMenuElement.uncached { [weak self] completion in
      guard let self else {
        completion([])
        return
      }
      let hasCheckedItems = !checklist.checkedItems.isEmpty
      var attributes: UIMenuElement.Attributes = entry == .delete ? .destructive : []
      // Held open only in the case that has something to say in place. With something to act on,
      // the tap opens a sheet or an alert and the menu should get out of the way as any other
      // entry does.
      if !hasCheckedItems {
        attributes.insert(.keepsMenuPresented)
      }
      let action = UIAction(title: Self.title(for: entry), image: Self.image(for: entry), attributes: attributes) { [weak self] _ in
        self?.checkedItemsEntryTapped(entry)
      }
      action.accessibilityIdentifier = Self.accessibilityIdentifier(for: entry)
      guard !hasCheckedItems, noItemsCheckedNoticeEntry == entry else {
        completion([action])
        return
      }
      // A disabled action is the closest a `UIMenu` comes to a caption: it draws as a plain row
      // rather than as something to press, which is what this is.
      let notice = UIAction(title: Self.noItemsCheckedNotice, attributes: .disabled) { _ in }
      completion([action, notice])
    }
  }

  private static func title(for entry: CheckedItemsMenuEntry) -> String {
    switch entry {
    case .copy: copyCheckedItemsMenuTitle
    case .move: moveCheckedItemsMenuTitle
    case .delete: deleteCheckedItemsMenuTitle
    }
  }

  /// Three distinct glyphs, none shared with a neighbour: Copy sits under Duplicate's
  /// `plus.square.on.square`, and Delete Checked Items over Delete Checklist's `trash`, and a shared
  /// glyph would make one read as the other.
  private static func image(for entry: CheckedItemsMenuEntry) -> UIImage? {
    switch entry {
    case .copy: UIImage(systemName: "doc.on.doc")
    case .move: UIImage(systemName: "arrow.turn.up.right")
    case .delete: UIImage(systemName: "checkmark.circle.badge.xmark")
    }
  }

  /// Locale-invariant handles for UI tests.
  private static func accessibilityIdentifier(for entry: CheckedItemsMenuEntry) -> String {
    switch entry {
    case .copy: "checklist.menu.copyCheckedItems"
    case .move: "checklist.menu.moveCheckedItems"
    case .delete: "checklist.menu.deleteCheckedItems"
    }
  }

  /// How long "No checked items." stays up: the same dwell a toast gets, copied rather than read
  /// from `ToastPresenter`, whose dwell is an initializer parameter.
  private static let noItemsCheckedNoticeDuration: Duration = .seconds(3)

  /// Internal so a test can invoke it, like the actions in this extension's doc comment.
  func checkedItemsEntryTapped(_ entry: CheckedItemsMenuEntry) {
    // Commits in-progress edits first; see `duplicateChecklist`.
    view.endEditing(true)
    guard !checklist.checkedItems.isEmpty else {
      showNoItemsCheckedNotice(under: entry)
      return
    }
    noItemsCheckedNoticeDismissal?.cancel()
    noItemsCheckedNoticeEntry = nil
    switch entry {
    case .copy: transferCheckedItems(.copy)
    case .move: transferCheckedItems(.move)
    case .delete: confirmDeleteCheckedItems()
    }
  }

  func transferCheckedItems(_ mode: CheckedItemsTransferMode) {
    onRequestTransferCheckedItems?(checklist.id, mode)
  }

  /// Puts "No checked items." under `entry` and takes it away again a moment later.
  ///
  /// Timed like a toast because the menu it lives in offers nothing else to retire it: it is not
  /// a row anyone can dismiss, and a bar-button menu does not report being closed. Tapping an
  /// entry again while it is up restarts the dwell, and moves the notice if it was another entry.
  private func showNoItemsCheckedNotice(under entry: CheckedItemsMenuEntry) {
    noItemsCheckedNoticeDismissal?.cancel()
    noItemsCheckedNoticeEntry = entry
    refreshMoreMenu()
    // The notice is a disabled row, which VoiceOver does not read out by itself appearing.
    postAccessibilityFeedback(focus: nil, announcement: Self.noItemsCheckedNotice)
    noItemsCheckedNoticeDismissal = Task { [weak self] in
      try? await Task.sleep(for: Self.noItemsCheckedNoticeDuration)
      guard !Task.isCancelled, let self, noItemsCheckedNoticeEntry != nil else { return }
      noItemsCheckedNoticeEntry = nil
      refreshMoreMenu()
    }
  }

  /// Rebuilds the overflow menu in place. Reassigning the bar item's menu is what makes one that
  /// is already on screen pick up a change; `.keepsMenuPresented` is what left it there to update.
  private func refreshMoreMenu() {
    moreBarButtonItem?.menu = makeMoreMenu()
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
    hasRequestedDismissal = true
    if let onRequestDismiss {
      onRequestDismiss()
    } else if let navigationController, navigationController.viewControllers.count > 1 {
      navigationController.popViewController(animated: true)
    } else {
      dismiss(animated: true)
    }
  }
}
