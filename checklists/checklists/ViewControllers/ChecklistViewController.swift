//
//  ChecklistViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 6/8/19.
//
// swiftlint:disable file_length

import SwiftData
import UIKit

private let itemsSection = 0
private let itemCellReuseIdentifier = "ItemCell"

/// How close to the top still counts as being at the top. An animated `setContentOffset` can land a
/// hair off its target, and an exact comparison that misses leaves `isResetting` stuck.
private let atTopTolerance: CGFloat = 0.5

/// Not a UITableViewController: its keyboard handling halted the animate-above-keyboard scroll and
/// jittered on long lists with lots of notes. Keyboard avoidance below is manual instead.
class ChecklistViewController: UIViewController {
  private var tableView: UITableView!
  var checklist: Checklist! // Expected to be set right after init(). Behavior undefined if this is set/reset after viewDidLoad().

  /// Set by the SwiftUI host (`ChecklistScreen`) so leaving the screen updates the router's
  /// navigation state instead of calling UIKit `dismiss`/`pop` directly — a UIKit dismissal of a
  /// SwiftUI-presented container would leave the router's sheet/selection out of sync with what's on
  /// screen.
  var onRequestDismiss: (() -> Void)?

  /// Set by the SwiftUI host (`ChecklistScreen`). Called with the new checklist's `id` after a
  /// duplication, for the host to present. The id rather than the model, like every other
  /// cross-screen reference in the app (see `Router.selectedChecklistID`); the controller has no router and should
  /// not acquire one. Unset means the copy is still made and saved, just not opened.
  var onRequestOpenDuplicate: ((String) -> Void)?

  /// Set by the SwiftUI host (`ChecklistScreen`). Called with *this* checklist's `id` when the
  /// overflow menu's copy or move entry is tapped, for the host to present the destination picker
  /// (see `CopyCheckedItemsView`). Unset means the entries do nothing.
  var onRequestTransferCheckedItems: ((String, CheckedItemsTransferMode) -> Void)?

  /// Set by the SwiftUI host (`ChecklistScreen`). Called when Export as PDF… could not make or
  /// write the PDF, for the host to say so.
  var onPDFExportFailed: (() -> Void)?

  /// Set by the SwiftUI host (`ChecklistScreen`). Called once as the screen closes because another
  /// device deleted its checklist, for the host to say why.
  var onRemoteDeletion: (() -> Void)?
  /// Whether this screen has asked to close, so a deletion arriving as a store change while it
  /// leaves — its own, or another device's just as the person left — isn't announced. Set by
  /// `requestDismissal`, and by `viewWillDisappear` for the SwiftUI stack's own back button and
  /// swipe, which bypass it.
  var hasRequestedDismissal = false
  /// Read at load: once the record is deleted, its properties are no longer safe to read.
  private var checklistID: String?

  /// Set by the SwiftUI host (`ChecklistScreen`). Called when a ⋯ menu entry that acts on the
  /// checked items is tapped with nothing checked, for the host to say why nothing happened.
  var onNoCheckedItems: (() -> Void)?

  /// The navigation bar's state, drawn by `ChecklistScreen`'s toolbar. Replaced by the host before
  /// the view loads; the default serves a screen built without one, such as a unit test's.
  var bar = ChecklistBar()

  /// Set by the SwiftUI host (`ChecklistScreen`), like `onRequestDismiss` above. There is no
  /// environment to read from here, so the client is pushed in. The console default means a missed
  /// injection degrades to "no events" rather than a crash — unlike `context` below, which has no
  /// safe default and must be set.
  var analytics: any AnalyticsClient = ConsoleAnalyticsClient()

  /// Set by the SwiftUI host, like `analytics` above. Fed one call per item checked off — the
  /// qualifying action for the automatic App Store review prompt. `nil` (tests, or a host
  /// without the coordinator in its environment) means the prompt is simply never fed.
  var ratingPrompt: RatingPromptCoordinator?

  /// Built in `setUpHeaderView`, once `isNewChecklist` is known. This and the four shortcuts below
  /// are only safe after `viewDidLoad` — some suites drive this controller without loading the view.
  private var checklistInfoHeaderView: ChecklistInfoHeaderView!
  private var statusIcon: CircularPercentStatusIcon {
    checklistInfoHeaderView.statusIcon
  }

  private var checklistNameTextField: CLTextField {
    checklistInfoHeaderView.nameTextField
  }

  private var captionView: UIStackView {
    checklistInfoHeaderView.captionView
  }

  private var checklistNotesTextView: CLTextView {
    checklistInfoHeaderView.notesTextView
  }

  private var remoteChangeObserver: RemoteChangeObserver?

  /// The store this screen reads and writes: the context `checklist` was resolved from. Same
  /// lifetime rule as `checklist`. There is no safe default, and a missed injection only traps in
  /// `viewDidLoad` for an empty checklist; otherwise it traps on the first edit or remote merge.
  var context: ModelContext!

  /// False only on the create sheet, where both caption lines could only ever read "Never".
  private var showsHistoryCaption = false

  /// Picks the overflow menu's wording: "Discard" on the create sheet, "Delete" otherwise.
  /// Captured once, like `showsHistoryCaption`, rather than read from `isNewChecklist` live —
  /// `viewDidAppear` clears that flag on every appearance, including the create sheet's own first
  /// one, so by the time the menu can ever be opened it already reads false.
  var showsDiscardWording = false

  var isNewChecklist: Bool = false
  var isJumpingToFirstItem: Bool = false
  var isResetting: Bool = false

  // For drag/reorder of cells.
  private var snapshotView: UIView = .init()
  private var sourceIndexPath: IndexPath = .init(row: 0, section: 0)

  /// Overrides how an item's new position is written. `nil` — the normal case — means the real
  /// write through `context`.
  ///
  /// An override rather than a direct call so tests can drive the failure path: a real SwiftData
  /// save only fails on a full or damaged disk, which a test has no way to arrange. Optional rather
  /// than a defaulted closure because a default value cannot capture `context`, which is unset at
  /// init time.
  var saveItemMove: ((Item, [Item], Int) throws -> Void)?

  /// Overrides what this screen tells VoiceOver after an action: the element to focus, and the
  /// announcement. Bar focus goes through `ChecklistBar.requestFocus` instead. `nil` — the normal case — posts both for real. Set by tests
  /// to observe them.
  var accessibilityFeedback: ((NSObject?, String?) -> Void)?

  /// How long after the bar's items are swapped VoiceOver is moved: long enough for the bar to relay
  /// and, entering Reorder Items mode, the ⋯ menu to close. `nil` moves it at once; set by tests, which
  /// cannot wait on the delay.
  var barSwapFocusDelay: Duration? = .milliseconds(500)
  /// The pending move, so a quick toggle back replaces it rather than stacking a second.
  var barSwapFocusTask: Task<Void, Never>?

  /// Whether Reorder Items mode is on. Named apart from `isEditing` because everywhere else in this
  /// screen "editing" means typing into a field.
  var isReordering: Bool {
    isEditing
  }

  override func loadView() {
    let tableView = UITableView(frame: .zero, style: .plain)
    self.tableView = tableView
    view = tableView
  }

  /// Builds the header and wires it to this controller. Layout lives in `ChecklistInfoHeaderView`.
  private func setUpHeaderView() {
    // Captured once, not read live: `viewDidAppear` clears `isNewChecklist`, so a caption keyed off
    // the flag would appear partway through the create sheet the moment an item was ticked.
    showsHistoryCaption = !isNewChecklist
    checklistInfoHeaderView = ChecklistInfoHeaderView(showsHistoryCaption: showsHistoryCaption)

    checklistNameTextField.delegate = self
    checklistNameTextField.text = checklist.name
    checklistNotesTextView.delegate = self
    checklistNotesTextView.text = checklist.notes
    refreshHistoryCaption()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardAppear(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    // Floating, docking, and resizing the window all move the keyboard without a show or hide.
    NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardAppear(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardDisappear(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    // Field focus rather than the keyboard drives the bar's Done, so it also shows with a hardware
    // keyboard. Notifications, because no one delegate hears all four fields begin.
    NotificationCenter.default.addObserver(self, selector: #selector(textEditingDidBegin(_:)), name: UITextField.textDidBeginEditingNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(textEditingDidBegin(_:)), name: UITextView.textDidBeginEditingNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(textEditingDidEnd(_:)), name: UITextField.textDidEndEditingNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(textEditingDidEnd(_:)), name: UITextView.textDidEndEditingNotification, object: nil)

    tableView.accessibilityIdentifier = "ChecklistTableView"
    tableView.delegate = self
    tableView.dataSource = self
    // Interactive, so only a drag into the keyboard dismisses it: scrolling up to read the rest of
    // the list leaves an edit in progress alone.
    tableView.keyboardDismissMode = .interactiveWithAccessory

    tableView.dragInteractionEnabled = true
    tableView.dragDelegate = self
    tableView.dropDelegate = self

    tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: itemCellReuseIdentifier)

    tableView.separatorStyle = .none
    // Pure spacing: nothing draws in a section header here, and with one section this is the only
    // gap between the header and the first row.
    tableView.sectionHeaderHeight = 8
    // Stated, because a plain-style table defaults this to an automatic non-zero pad that would
    // stack on top of the height above and put the real gap out of reach of either number.
    tableView.sectionHeaderTopPadding = 0
    tableView.sectionFooterHeight = 28
    tableView.backgroundColor = Colors.defaultBackground

    setUpHeaderView()
    tableView.tableHeaderView = checklistInfoHeaderView

    let tableFooterView = AddItemButtonTableFooterView(frame: .zero)
    tableFooterView.delegate = self
    tableView.tableFooterView = tableFooterView

    updateStatusIcon()

    // The footer's width isn't set automatically despite the docs; set it manually.
    tableFooterView.widthAnchor.constraint(equalTo: tableView.widthAnchor, multiplier: 1.0).isActive = true

    configureBar()

    registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (viewController: Self, _) in
      viewController.textSizeDidChange()
    }

    if checklist.items.isEmpty {
      try? context.insert(item: Item(), at: 0, in: checklist)
    }

    checklistID = checklist.id
    // Refreshes when another device's changes are merged in via CloudKit sync.
    remoteChangeObserver = RemoteChangeObserver { [weak self] in
      self?.handleRemoteChange()
    }
    // And when ChecklistsView, beside this screen on a wide window, resets it.
    NotificationCenter.default.addObserver(self, selector: #selector(checklistsDidReset), name: ModelContext.didResetChecklists, object: nil)
  }

  @objc private func checklistsDidReset() {
    handleRemoteChange()
  }

  /// Reacts to this checklist being changed, or deleted, somewhere other than this screen.
  ///
  /// Internal so a test can drive it without waiting out the observer's debounce.
  func handleRemoteChange() {
    guard !checklist.isDeleted, context.checklist(checklist.persistentModelID) != nil else {
      // Deleted on another device, or by sample dedupe, while open here. Leaving the screen up
      // would let the user keep editing a record that no longer exists. Looked up by record, not
      // `id`: dedupe deletes one of two records sharing an `id`, and the twin must not count.
      // Said only for another device's delete, and once: dedupe leaves the same checklist under its
      // twin, and this screen's own Delete Checklist has already asked to close.
      let deletedElsewhere = !hasRequestedDismissal && checklistID.map { context.checklist(id: $0) == nil } ?? false
      requestDismissal()
      if deletedElsewhere {
        onRemoteDeletion?()
      }
      return
    }

    // Never yank the table out from under an active edit; the merged values are already in the
    // model and will show on the next natural reload.
    // Nor in the middle of a row drag, which a reload cuts short or leaves out of step.
    guard !tableView.hasActiveDrag, !tableView.hasUncommittedUpdates, !isEditingText
    else { return }

    checklistNameTextField.text = checklist.name
    checklistNotesTextView.text = checklist.notes
    // Notes from another device can be any length.
    headerContentDidChange()
    updateStatusIcon()
    // Cheap now the caption is a fixed height: another device's tick shows up without a reopen.
    refreshHistoryCaption()
    // Only rows that no longer match the store are refreshed, in place. A reload re-deals every
    // visible cell to a different row, so a long-press lift in progress draws a second row on top
    // of the pressed one. CloudKit echoing this screen's own save back touches no row at all.
    // TECH DEBT: We should come up with a more holistic way to handle to inbound iCloud sync changes
    // in a way that minimally interferes with the user's experience. While still fixing the original
    // issue of iCloud updates from reordering causing glitchy UI behaviors on an immediate, second
    // tap-hold, reorder event. Here, we made the smallest fix, kept small to ship with the release.
    // A row-count change landing mid-press still reloads and can still glitch, and a real change to
    // the pressed row rewrites it mid-press. Holding refreshes back while a press, menu or drag is up
    // would close that; worth proposing once there is time to test it on device. See #461.
    let items = checklist.items
    if tableView.numberOfRows(inSection: itemsSection) == items.count {
      let staleRows = (tableView.indexPathsForVisibleRows ?? []).filter { indexPath in
        guard let cell = tableView.cellForRow(at: indexPath) as? ItemTableViewCell else { return true }
        return !cell.itemContentView.isShowing(items[indexPath.row])
      }
      if !staleRows.isEmpty {
        tableView.reconfigureRows(at: staleRows)
      }
    } else {
      tableView.reloadData()
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if isNewChecklist {
      isNewChecklist = false // safeguard against future times viewWillAppear/viewDidAppear might get called.
      // Return in the name field moves on to the seeded blank row. A checklist that opens with
      // items of its own, as one made from copied items does, has no such row to move to.
      isJumpingToFirstItem = checklist.items.count == 1 && checklist.items[0].name.isEmpty
      checklistNameTextField.becomeFirstResponder()
    } else {
      tableView.flashScrollIndicators()
    }
    analytics.track(AnalyticsEvent.checklistViewed, properties: checklist.analyticsViewedProperties)
  }

  override func viewWillDisappear(_ animated: Bool) {
    // Forces the resignFirstResponder commit synchronously, rather than the usual late landing near
    // the end of the pop transition, covering two ordering hazards:
    //   - Header fields must commit before this screen disappears, or ChecklistsView's `@Query`
    //     shows the pre-edit value until some unrelated store change refreshes it.
    //   - Item cells must commit before viewDidDisappear's dangling-empty-item trim loop, or an
    //     uncommitted name reads as empty and gets wrongly deleted.
    view.endEditing(true)
    // Leaving by the host's back button or swipe, which bypass `requestDismissal`. A back swipe
    // given up partway brings the screen back, so it takes the mark back too.
    if parent?.isMovingFromParent == true {
      hasRequestedDismissal = true
      transitionCoordinator?.notifyWhenInteractionChanges { [weak self] context in
        if context.isCancelled {
          self?.hasRequestedDismissal = false
        }
      }
    }
    super.viewWillDisappear(animated)
  }

  override func viewDidDisappear(_ animated: Bool) {
    // A deleted checklist has no trailing rows left to tidy, and reading the relationship off it
    // would touch an invalidated model.
    guard !checklist.isDeleted else {
      super.viewDidDisappear(animated)
      return
    }
    // If user left some 'dangling' empty items at end of list, remove them, but don't worry if there's one lone empty item.
    // Snapshotted up front: deleting from the context does not re-sort this array, so walking a
    // stale copy backwards is both correct and cheaper than recomputing the sorted items each step.
    let items = checklist.items
    var didDelete = false
    var i = items.count - 1
    while i > 0 {
      let item = items[i]
      if item.isBlank {
        context.delete(item)
        didDelete = true
      } else {
        break
      }
      i -= 1
    }
    if didDelete {
      // No completion to record: `isComplete` already ignores blank rows, so removing them cannot
      // change it.
      context.saveChangesIgnoringFailure(operation: .delete)
    }
    super.viewDidDisappear(animated)
  }

  /// Reorder Items mode: a drag handle on every row, and nothing else that takes a tap. The header's
  /// name and notes, each row's checkbox and text, and the add-item footer all freeze, so the only
  /// things that respond are the ones the mode is about. Deleting stays outside the mode.
  override func setEditing(_ editing: Bool, animated: Bool) {
    guard editing != isEditing else { return }
    if editing {
      // Commits whatever is being typed before the field it belongs to stops responding.
      view.endEditing(true)
    }
    super.setEditing(editing, animated: animated)
    tableView.setEditing(editing, animated: animated)
    bar.setMode(editing ? .reordering : (isEditingText ? .typing : .idle), animated: animated)
    moveVoiceOverAfterBarSwap()

    checklistNameTextField.isEnabled = !editing
    checklistNotesTextView.isEditable = !editing
    for case let cell as ItemTableViewCell in tableView.visibleCells {
      cell.itemContentView.setReordering(editing)
    }
    refreshAccessibilityActions()
    tableView.tableFooterView?.isUserInteractionEnabled = !editing
    // The footer's content rather than the footer itself: the table puts its footer view back to
    // full opacity when it animates a row move, which would bring the Add button back mid-mode.
    let footerContent = (tableView.tableFooterView as? AddItemButtonTableFooterView)?.contentView
    let fadeFooter: () -> Void = { footerContent?.alpha = editing ? 0.0 : 1.0 }
    if animated {
      UIView.animate(withDuration: 0.25, animations: fadeFooter)
    } else {
      fadeFooter()
    }
  }

  /// The VoiceOver escape gesture leaves Reorder Items mode, which hides the back button.
  override func accessibilityPerformEscape() -> Bool {
    guard isReordering else { return super.accessibilityPerformEscape() }
    setEditing(false, animated: true)
    return true
  }

  func doneButtonTapped() {
    // Commits whatever is being typed before leaving, since the create sheet's Done stays in the bar
    // while typing. Left to `viewWillDisappear`, it lands after the router has closed the sheet, and
    // the source screen of a move has already named the new checklist in its toast by then.
    view.endEditing(true)
    requestDismissal()
  }

  func resetButtonTapped() {
    analytics.track(AnalyticsEvent.checklistReset)

    // Nothing ticked means nothing to update: a Reset on an untouched list must not date it.
    let wasComplete = checklist.isComplete
    if checklist.uncheckAllItems() {
      context.saveStatusChange(to: checklist, wasComplete: wasComplete)
      refreshHistoryCaption()
      // Only when something changed: on a list with nothing ticked, nothing changes on screen either.
      postAccessibilityFeedback(focus: nil, announcement: Self.allItemsUncheckedAnnouncement)
    }
    updateStatusIcon()

    if Self.isAtTop(tableView) {
      tableView.reloadData()
    } else if UIAccessibility.isReduceMotionEnabled {
      // The trip to the top is functional; gliding there is not. Jump, and reload directly rather
      // than waiting on the `isResetting` handoff in `scrollViewDidScroll`, which needs the
      // animation's intermediate offsets to land on.
      tableView.setContentOffset(topContentOffset, animated: false)
      tableView.reloadData()
    } else {
      isResetting = true
      scrollToTop()
    }
  }

  /// The table's resting offset at the top. Zero only when nothing is inset above the content;
  /// under the navigation bar the top is the negative of the adjusted inset.
  private var topContentOffset: CGPoint {
    CGPoint(x: 0.0, y: -tableView.adjustedContentInset.top)
  }

  /// Whether a scroll view is resting at its top, inset included.
  ///
  /// Static and internal so a test can drive it with a stub whose `adjustedContentInset` it chose.
  static func isAtTop(_ scrollView: UIScrollView) -> Bool {
    scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + atTopTolerance
  }

  private func scrollToTop() {
    tableView.setContentOffset(topContentOffset, animated: true)
  }

  func insertNewItem(becomeFirstResponder: Bool) {
    insertNewItem(at: checklist.items.count, becomeFirstResponder: becomeFirstResponder)
  }

  private func insertNewItem(at index: Int, becomeFirstResponder: Bool) {
    do {
      try context.insert(item: Item(), at: index, in: checklist)
    } catch {
      return // `saveChanges` told the person, and the insert has taken the item back out.
    }

    let updates = {
      self.tableView.performBatchUpdates({
        self.collapseEditingCellIfNecessary()
        self.tableView.insertRows(at: [IndexPath(row: index, section: itemsSection)], with: .top)
      }, completion: nil)
    }

    let startEditingBlock: ((Bool) -> Void) = { success in
      if success {
        let indexPath = IndexPath(row: index, section: itemsSection)
        guard let cell = self.tableView.cellForRow(at: indexPath) as? ItemTableViewCell else { assertionFailure(); return }
        // Explicit scroll needed: becomeFirstResponder alone doesn't reliably scroll the new row into view.
        self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        cell.itemContentView.startEditing()
      }
    }
    // Duration matters for correctness, not just polish: too slow and fast-typing-after-Return
    // sends the letters into the prior cell instead of the new one.
    UIView.animate(withDuration: 0.01, animations: updates, completion: becomeFirstResponder ? startEditingBlock : nil)

    updateStatusIcon()
    refreshAccessibilityActions()
  }

  /// Moves typing to the item at `index`, scrolling it on screen first so its cell exists.
  func startEditingRow(at index: Int) {
    let indexPath = IndexPath(row: index, section: itemsSection)
    tableView.scrollToRow(at: indexPath, at: .none, animated: false)
    tableView.layoutIfNeeded()
    (tableView.cellForRow(at: indexPath) as? ItemTableViewCell)?.itemContentView.startEditing()
  }

  private func collapseEditingCellIfNecessary() {
    for cell in tableView.visibleCells {
      if let cell = cell as? ItemTableViewCell, cell.itemContentView.isEditing {
        cell.itemContentView.refreshHeight()
      }
    }
  }

  func cellHeightRequiresRefresh(animated: Bool) {
    if animated {
      tableView.beginUpdates()
      tableView.endUpdates()
    } else {
      // When table view is scrolled up a bit and user types in text view, jitters without this.
      // Scoped, not a global toggle back to `true`: that would undo `TestAnimationsOverride`.
      UIView.performWithoutAnimation {
        tableView.beginUpdates()
        tableView.endUpdates()
      }
    }
  }

  /// `announcesResult` is for the swipe, context-menu and VoiceOver Delete, which move VoiceOver to
  /// the row that takes the deleted one's place. Backspace on an empty row leaves it off: it moves
  /// editing to the row above itself. `afterMenu`: see `postAccessibilityFeedback`.
  func deleteItem(at index: Int, announcesResult: Bool = false, afterMenu: Bool = false) {
    let items = checklist.items
    guard index >= 0, index < items.count else { assertionFailure(); return }
    let wasComplete = checklist.isComplete
    context.delete(items[index])
    context.saveDeletion(from: checklist, wasComplete: wasComplete)
    tableView.deleteRows(at: [IndexPath(item: index, section: itemsSection)], with: .fade)
    updateStatusIcon()
    refreshHistoryCaption()
    refreshAccessibilityActions()
    guard announcesResult else { return }
    let neighbour = DeletionFocus.neighbourIndex(afterRemoving: index, remainingCount: checklist.items.count)
    postAccessibilityFeedback(focus: focusTargetAfterRemoval(neighbour: neighbour), announcement: Self.itemDeletedAnnouncement, afterMenu: afterMenu)
  }

  /// The overflow menu's Delete Checked Items, once confirmed. Internal so a test can invoke it: a
  /// `UIAction` handler cannot be fired directly.
  ///
  /// Reloads rather than deleting rows one by one: the checked rows can sit anywhere in the list,
  /// and nothing about a scattered multi-row fade tells the person more than the rows being gone.
  func deleteCheckedItems() {
    let checkedItems = checklist.checkedItems
    guard !checkedItems.isEmpty else { return }
    analytics.track(
      AnalyticsEvent.checklistCheckedItemsDeleted,
      properties: [AnalyticsProperty.itemsCount: checkedItems.count],
    )
    context.deleteItems(checkedItems, from: checklist)
    // The reload re-issues every row's VoiceOver actions, so no `refreshAccessibilityActions` here.
    tableView.reloadData()
    updateStatusIcon()
    refreshHistoryCaption()
    // The reload drops whatever row VoiceOver was on, so it starts again from the top.
    postAccessibilityFeedback(
      focus: focusTargetAfterRemoval(neighbour: checklist.items.isEmpty ? nil : 0),
      announcement: Self.checkedItemsDeletedAnnouncement(count: checkedItems.count),
    )
  }

  /// Copies the item at `index` and places the copy directly beneath it. See
  /// `ModelContext.duplicate(item:in:)` — unlike checklist duplication, the name carries over
  /// unchanged. `afterMenu`: see `postAccessibilityFeedback`.
  func duplicateItem(at index: Int, afterMenu: Bool = false) {
    // Commits in-progress edits first; see `duplicateChecklist`.
    view.endEditing(true)
    let items = checklist.items
    guard index >= 0, index < items.count else { assertionFailure(); return }
    guard (try? context.duplicate(item: items[index], in: checklist)) != nil else { return }
    analytics.track(AnalyticsEvent.checklistItemDuplicated)
    tableView.insertRows(at: [IndexPath(row: index + 1, section: itemsSection)], with: .automatic)
    // Not a status change: no timestamp write, no history-caption refresh — matches
    // `insertNewItem`. The new unchecked row can still move `percentageComplete` and flip
    // `isComplete`, which is why the status icon alone needs a refresh.
    updateStatusIcon()
    refreshAccessibilityActions()
    postAccessibilityFeedback(focus: nil, announcement: Self.itemDuplicatedAnnouncement, afterMenu: afterMenu)
  }

  /// The width the header was last measured against. `view` is the table itself, so this runs on
  /// every scroll frame — and measuring means a full layout plus TextKit pass over the notes.
  private var lastHeaderWidth: CGFloat = 0.0

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if footerNeedsResize, let footer = tableView.tableFooterView as? AddItemButtonTableFooterView {
      footerNeedsResize = false
      // Like the header, the table reads the footer's height only on assignment.
      if footer.adjustFrameHeight() {
        tableView.tableFooterView = footer
      }
    }
    guard tableView.bounds.width != lastHeaderWidth else { return }
    lastHeaderWidth = tableView.bounds.width
    checklistInfoHeaderView?.resize(in: tableView)
  }

  /// Re-measures the header after its content changes. Clearing the cached width also covers the
  /// case where the table has no width yet: the next layout pass measures instead.
  private func headerContentDidChange() {
    lastHeaderWidth = 0.0
    checklistInfoHeaderView?.resize(in: tableView)
  }

  /// Set by a text-size change; the footer re-measures in the next layout pass.
  private var footerNeedsResize = false

  /// Every font on this screen rescales itself, and the table re-measures its rows, but the header
  /// and footer are frame-sized: they only change height when re-measured and reassigned.
  ///
  /// This runs in the trait pass, before the views below have their new fonts, so it measures
  /// nothing itself: the next layout pass does, once they have them.
  private func textSizeDidChange() {
    lastHeaderWidth = 0.0
    footerNeedsResize = true
    view.setNeedsLayout()
  }

  func updateStatusIcon() {
    statusIcon.percentageComplete = checklist.percentageComplete
  }

  /// A text swap: the fixed line count means this needs none of the header re-measuring
  /// `textViewDidChange` does for the notes.
  private func refreshHistoryCaption() {
    guard showsHistoryCaption else { return }
    ChecklistHistoryCaption.refresh(captionView, for: checklist)
  }

  /// Saves an item's new position, reporting whether it stuck.
  ///
  /// A failure is already logged and reported by `saveChanges`, and the move itself is undone in
  /// the model, so what is left for the caller is the screen: the two reorder paths differ in what
  /// they have already drawn, so each decides for itself what to do about it.
  func saveMove(of item: Item, among siblings: [Item], to index: Int) -> Bool {
    do {
      if let saveItemMove {
        try saveItemMove(item, siblings, index)
      } else {
        try context.move(item: item, among: siblings, to: index)
      }
      return true
    } catch {
      return false
    }
  }

  /// Puts the table back in step with the model after a move that could not be saved.
  ///
  /// Deferred to a later turn of the run loop deliberately: reloading from inside
  /// `tableView(_:moveRowAt:to:)` fights the move animation that is still in flight, which can
  /// assert or leave the table in a broken state.
  ///
  /// Overridden in tests to observe that a failure asked for a resync.
  func resyncAfterFailedMove() {
    Task { @MainActor [weak self] in
      self?.tableView.reloadData()
    }
  }
}

extension ChecklistViewController: UITableViewDataSource {
  func numberOfSections(in _: UITableView) -> Int {
    1
  }

  func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
    checklist.items.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    assert(indexPath.row >= 0 && indexPath.row < checklist.items.count && indexPath.section == itemsSection)
    guard let cell = tableView.dequeueReusableCell(withIdentifier: itemCellReuseIdentifier, for: indexPath) as? ItemTableViewCell else { assertionFailure(); return UITableViewCell() }
    cell.itemContentView.item = checklist.items[indexPath.row]
    cell.itemContentView.delegate = self
    // Applied on every dequeue, so a reload — a remote merge included — keeps the mode's state.
    cell.itemContentView.setReordering(isReordering)
    cell.itemContentView.setAccessibilityActions(accessibilityActions(for: checklist.items[indexPath.row]))
    return cell
  }

  func tableView(_: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    guard indexPath.section == itemsSection else { assertionFailure(); return false }
    return true
  }

  func tableView(_: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    let items = checklist.items
    guard sourceIndexPath.row < items.count else { assertionFailure(); return }
    // UIKit has already drawn the row in its new position, so a failed save leaves the table
    // showing an order the model no longer holds and it has to be put back.
    if !saveMove(of: items[sourceIndexPath.row], among: items, to: destinationIndexPath.row) {
      resyncAfterFailedMove()
    }
    refreshAccessibilityActions()
  }
}

extension ChecklistViewController: UITableViewDelegate {
  func tableView(_: UITableView, shouldHighlightRowAt _: IndexPath) -> Bool {
    false
  }

  /// Handles only: Reorder Items mode does what its name says, and deleting stays outside it.
  func tableView(_: UITableView, editingStyleForRowAt _: IndexPath) -> UITableViewCell.EditingStyle {
    .none
  }

  /// With no delete button to make room for, rows keep their place when the mode turns on.
  func tableView(_: UITableView, shouldIndentWhileEditingRowAt _: IndexPath) -> Bool {
    false
  }

  /// Delete keeps the outermost slot and the full-swipe gesture; Duplicate sits beside it,
  /// matching the list screen's ordering (`ChecklistsView.swift`).
  func tableView(_: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard indexPath.section == itemsSection, indexPath.row < checklist.items.count else { assertionFailure(); return nil }
    guard !isReordering else { return nil }

    let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
      self?.deleteItem(at: indexPath.row, announcesResult: true)
      completion(true)
    }
    deleteAction.image = UIImage(systemName: "trash")
    deleteAction.backgroundColor = Colors.destructiveFill
    deleteAction.accessibilityLabel = CommonStrings.delete

    let duplicateAction = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, completion in
      self?.duplicateItem(at: indexPath.row)
      completion(true)
    }
    duplicateAction.image = UIImage(systemName: "plus.square.on.square")
    duplicateAction.backgroundColor = Colors.accentFill
    duplicateAction.accessibilityLabel = CommonStrings.duplicate

    let configuration = UISwipeActionsConfiguration(actions: [deleteAction, duplicateAction])
    configuration.performsFirstActionWithFullSwipe = true
    return configuration
  }

  /// The swipe actions again, for long-press and right-click. The table's long-press drag still
  /// works: moving the finger once the menu is up lifts the row into the drag (see the drag
  /// extension below for what that relies on). Absent in Reorder Items mode, like the swipe. Looks
  /// the item up again when an action fires, since its row may have moved meanwhile.
  func tableView(_: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point _: CGPoint) -> UIContextMenuConfiguration? {
    guard indexPath.section == itemsSection, indexPath.row < checklist.items.count, !isReordering else { return nil }
    let item = checklist.items[indexPath.row]

    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
      let duplicate = UIAction(title: CommonStrings.duplicate, image: UIImage(systemName: "plus.square.on.square")) { _ in
        guard let self, let index = self.checklist.items.firstIndex(where: { $0 === item }) else { return }
        self.duplicateItem(at: index, afterMenu: true)
      }
      let delete = UIAction(title: CommonStrings.delete, image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
        guard let self, let index = self.checklist.items.firstIndex(where: { $0 === item }) else { return }
        // Commits an edit in progress first, as Duplicate does: a right-click or a long-press on
        // the checkbox can reach the row being typed in, whose text would otherwise be written to
        // the deleted item when its field stops editing.
        self.view.endEditing(true)
        self.deleteItem(at: index, announcesResult: true, afterMenu: true)
      }
      return UIMenu(children: [duplicate, delete])
    }
  }
}

extension ChecklistViewController: UIScrollViewDelegate {
  /// How far the list scrolls before the name moves into the navigation bar: to the bottom of the
  /// name's text, which moves with the text size. `52.0`, where that bottom sits at the default size,
  /// stands in before the header exists.
  var titleThresholdY: CGFloat {
    checklistInfoHeaderView?.nameTextBottom ?? 52.0
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    // Measured from the table's real top rather than a literal zero, so the threshold below means
    // the distance actually scrolled.
    let scrolledY: CGFloat = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    let thresholdY: CGFloat = titleThresholdY

    if isResetting == true, Self.isAtTop(scrollView) {
      isResetting = false
      tableView.reloadData()
    }
    // Only on crossing the threshold, as the name is read: not on every scroll frame.
    let isPastThreshold = scrolledY > thresholdY
    if isPastThreshold != (bar.title != nil) {
      bar.setTitle(isPastThreshold ? checklist.name : nil)
    }
  }
}

// MARK: - Keyboard dynamics.

/// https://developer.apple.com/library/archive/documentation/StringsTextFonts/Conceptual/TextAndWebiPhoneOS/KeyboardManagement/KeyboardManagement.html
extension ChecklistViewController {
  /// How much of `tableBounds` the keyboard covers from below, in the table's own (content)
  /// coordinates. Zero when the keyboard misses the table entirely: floating, undocked, or below a
  /// window that does not reach the bottom of the screen.
  ///
  /// Static and internal so a test can drive it with frames it chose.
  static func keyboardOverlap(keyboardFrame: CGRect, tableBounds: CGRect) -> CGFloat {
    guard keyboardFrame.intersects(tableBounds) else { return 0.0 }
    return max(0.0, tableBounds.maxY - keyboardFrame.minY)
  }

  @objc func onKeyboardAppear(_ notification: NSNotification) {
    guard
      let userInfo = notification.userInfo,
      let screenKeyboardFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
    else { assertionFailure(); return }

    guard let cell = findEditingCell()
    else { return } // If keyboard arose for Checklist Name/Notes, which, if visible, shouldn't require scrolling (except for massive notes, but we're accepting that for now).

    // The frame is in screen coordinates.
    guard let screen = view.window?.windowScene?.screen else { return }
    let keyboardFrame = tableView.convert(screenKeyboardFrame, from: screen.coordinateSpace)
    var keyboardHeight = Self.keyboardOverlap(keyboardFrame: keyboardFrame, tableBounds: tableView.bounds)
    guard keyboardHeight > 0.0 else {
      onKeyboardDisappear(notification)
      return
    }

    keyboardHeight += 20.0 // Breathing room between the edited row and the keyboard. (iPhone X-style phones used to get 34pt more, from counting the home-indicator strip the table doesn't cover.)

    // `cell.frame` below is in the table's content space; `tableView.frame` is in its superview's,
    // and the two only line up at a content offset of zero. `bounds` is content space, so
    // inset it by the bar above and the keyboard below to get the genuinely visible slice.
    let visibleFrame = tableView.bounds.inset(by: UIEdgeInsets(
      top: tableView.adjustedContentInset.top,
      left: 0.0,
      bottom: keyboardHeight,
      right: 0.0,
    ))

    let cellFrame = tableView.convert(cell.frame, from: cell.superview)

    let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardHeight, right: 0.0)
    // If the user taps to edit and quickly starts typing, the default animated scrollRectToVisible
    // halts the animation — this explicit animation block avoids that, and is snappier besides.
    UIView.animate(withDuration: 0.1) {
      self.tableView.contentInset = contentInsets
      self.tableView.scrollIndicatorInsets = contentInsets
      if !visibleFrame.contains(cellFrame) { // If even partially covered, move it.
        self.tableView.scrollRectToVisible(cellFrame, animated: false)
      }
    }
  }

  @objc func onKeyboardDisappear(_: NSNotification) {
    UIView.animate(withDuration: 0.1) { // At bottom of list, it will animate back down more smoothly.
      self.tableView.contentInset = .zero
      self.tableView.scrollIndicatorInsets = .zero
    }
  }

  func findEditingCell() -> UITableViewCell? {
    for cell in tableView.visibleCells {
      if let cell = cell as? ItemTableViewCell, cell.itemContentView.isEditing {
        return cell
      }
    }
    return nil
  }

  /// Whether any field on this screen is being typed into: the checklist's name or notes, or an
  /// item's.
  var isEditingText: Bool {
    checklistNameTextField.isFirstResponder || checklistNotesTextView.isFirstResponder || findEditingCell() != nil
  }

  /// Whether an input method is mid-word in the field being typed into.
  var isComposingText: Bool {
    if checklistNameTextField.isFirstResponder {
      return checklistNameTextField.markedTextRange != nil
    }
    if checklistNotesTextView.isFirstResponder {
      return checklistNotesTextView.markedTextRange != nil
    }
    return (findEditingCell() as? ItemTableViewCell)?.itemContentView.isComposingText ?? false
  }

  @objc func textEditingDidBegin(_ notification: Notification) {
    guard (notification.object as? UIView)?.isDescendant(of: view) == true else { return }
    updateBarMode(animated: true)
  }

  /// Waits a turn before taking the editing Done away: moving between fields ends one and begins the
  /// next in the same turn, and updating the bar on each would flicker the button. Common modes, so a list drag
  /// that ends editing doesn't leave Done up until the drag lets go.
  ///
  /// Unfiltered, unlike the begin side: a row's field can already be out of the view when it
  /// resigns (a reload for a text-size change, a swipe-delete), and the update reads the screen's
  /// own fields afresh anyway.
  @objc func textEditingDidEnd(_: Notification) {
    RunLoop.main.perform(inModes: [.common]) { [weak self] in
      MainActor.assumeIsolated {
        self?.updateBarMode(animated: true)
      }
    }
  }
}

/// For the Checklist Name field.
extension ChecklistViewController: UITextFieldDelegate {
  func textFieldDidBeginEditing(_ textField: UITextField) {
    if textField.hasText {
      isJumpingToFirstItem = false // Handling odd use case.
    }
  }

  func textFieldDidEndEditing(_: UITextField) {
    checklist.name = checklistNameTextField.hasText ? checklistNameTextField.text ?? CommonStrings.defaultChecklistName : CommonStrings.defaultChecklistName // Accounts for both nil and empty string.
    context.saveChangesIgnoringFailure(operation: .checklistEdit)
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    if isJumpingToFirstItem {
      isJumpingToFirstItem = false
      // Empty only when the seeded row's save failed and was taken back out; the toast has said so.
      guard !checklist.items.isEmpty else { return false }
      guard
        checklist.items.count == 1,
        let cell = tableView.cellForRow(at: IndexPath(row: 0, section: itemsSection)) as? ItemTableViewCell
      else { assertionFailure(); return false }

      cell.itemContentView.startEditing()
    }
    return false
  }
}

/// For the Checklist Notes field.
extension ChecklistViewController: UITextViewDelegate {
  func textViewDidEndEditing(_: UITextView) {
    checklist.notes = checklistNotesTextView.text
    context.saveChangesIgnoringFailure(operation: .checklistEdit)
  }

  func textViewDidChange(_: UITextView) {
    headerContentDidChange()
  }
}

extension ChecklistViewController: AddItemButtonTableFooterViewDelegate {
  func addItemTableViewCellTapped() {
    insertNewItem(becomeFirstResponder: true)
  }
}

// MARK: - Drag/Drop Reorder

/// The rows' context menu hands off to this drag once the finger moves. That relies on
/// `CLTextView` having no text drag interaction of its own: with one under the finger, the menu
/// opens and the drag never starts.
extension ChecklistViewController: UITableViewDragDelegate {
  func tableView(_: UITableView, itemsForBeginning _: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
    guard indexPath.section == itemsSection, indexPath.row < checklist.items.count else { assertionFailure(); return [] }
    return checklist.items[indexPath.row].dragItems()
  }
}

extension ChecklistViewController: UITableViewDropDelegate {
  func tableView(_: UITableView, canHandle session: UIDropSession) -> Bool {
    session.canLoadObjects(ofClass: NSString.self)
  }

  func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath _: IndexPath?) -> UITableViewDropProposal {
    if tableView.hasActiveDrag {
      if session.items.count > 1 {
        UITableViewDropProposal(operation: .cancel)
      } else {
        UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
      }
    } else { // dropped from external to app
      UITableViewDropProposal(operation: .cancel)
    }
  }

  func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
    // `coordinator.destinationIndexPath` is nil when the drop lands past the last row (e.g. the user
    // drags below the bottom of the list). Clamped to `count - 1` because `tableView.moveRow` would
    // otherwise get an out-of-range index path; the sort-key reorder would append either way.
    let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(row: checklist.items.count - 1, section: itemsSection)
    assert(coordinator.items.count == 1)
    guard let dropItem = coordinator.items.first else { assertionFailure(); return }
    let itemProvider = dropItem.dragItem.itemProvider
    itemProvider.loadObject(ofClass: NSString.self) { string, _ in
      guard let itemId = string as? String else { return }
      Task { @MainActor in
        let items = self.checklist.items
        guard let sourceIndex = items.firstIndex(where: { $0.id == itemId }) else { return }
        // Unlike the reorder-control path above, nothing has moved on screen yet, so the row is
        // only moved once the new order is actually saved.
        guard self.saveMove(of: items[sourceIndex], among: items, to: destinationIndexPath.row) else { return }
        tableView.moveRow(at: IndexPath(row: sourceIndex, section: destinationIndexPath.section), to: destinationIndexPath)
        self.refreshAccessibilityActions()
      }
    }
  }
}

// MARK: - ItemContentViewDelegate - responding to cell events.

extension ChecklistViewController: ItemContentViewDelegate {
  func itemContentViewDidFinishEditing(_: ItemContentView) {
    cellHeightRequiresRefresh(animated: true)
  }

  func itemContentViewCheckboxButtonTapped(_ itemContentView: ItemContentView) {
    toggleItem(in: itemContentView)
  }

  /// The checkbox square's tap, and ⌘K on the item being typed in.
  func toggleItem(in itemContentView: ItemContentView) {
    // The row ignores touches in Reorder Items mode; this also covers a VoiceOver double-tap.
    guard !isReordering, let item = itemContentView.item else { return }
    let wasComplete = checklist.isComplete
    item.toggleStatus()
    context.saveStatusChange(to: checklist, wasComplete: wasComplete)
    itemContentView.updateCheckedStatus()
    updateStatusIcon()
    refreshHistoryCaption()
    // Only a check counts toward the review prompt; unchecking reads as a reset, not progress.
    if item.status == .checked {
      ratingPrompt?.recordItemChecked()
    }
  }

  func itemContentViewNameFieldDidBeginEditing(_ itemContentView: ItemContentView) {
    itemContentView.updateTextViewHeight(isExpanded: true)
    cellHeightRequiresRefresh(animated: true)
  }

  func itemContentViewHeightUpdated(_ itemContentView: ItemContentView) {
    // Don't animate, or stuff gets jittery when table view is scrolled up and user is typing in text view.
    cellHeightRequiresRefresh(animated: false)
    scrollCaretIntoView(of: itemContentView)
  }

  /// Keeps the line being typed above the keyboard as a row grows.
  ///
  /// The table's layout pass after a row resizes puts the content offset back
  /// so the focused field holds its place on screen, undoing any scroll made before it, UIKit's
  /// own scroll to the caret included. So the layout runs first, here, and the scroll after it.
  private func scrollCaretIntoView(of itemContentView: ItemContentView) {
    tableView.layoutIfNeeded()
    guard let caret = itemContentView.editingCaretRect else { return }
    tableView.scrollRectToVisible(tableView.convert(caret, from: itemContentView), animated: false)
  }

  func itemContentView(_ itemContentView: ItemContentView, nameFieldUpdatedWith name: String) {
    itemContentView.item?.name = name
    context.saveChangesIgnoringFailure(operation: .itemEdit)
  }

  func itemContentView(_ itemContentView: ItemContentView, notesFieldUpdatedWith notes: String) {
    itemContentView.item?.notes = notes
    context.saveChangesIgnoringFailure(operation: .itemEdit)
  }

  func itemContentViewDidReturnOnNameField(_ itemContentView: ItemContentView) {
    guard
      let item = itemContentView.item,
      let index = checklist.items.firstIndex(where: { $0.id == item.id })
    else { assertionFailure(); return }
    insertNewItem(at: index + 1, becomeFirstResponder: true)
  }

  func itemContentViewDidBackspaceEmpty(_ itemContentView: ItemContentView) {
    guard
      let item = itemContentView.item,
      let index = checklist.items.firstIndex(where: { $0.id == item.id })
    else { assertionFailure(); return }

    guard index > 0 else { return } // Nothing happens if backspaced on first item in list.

    let nextCellActionBlock = {
      if let cell = self.tableView.cellForRow(at: IndexPath(row: index - 1, section: itemsSection)) as? ItemTableViewCell {
        cell.itemContentView.startEditing()
        self.deleteItem(at: index)
      }
    }

    /*
     If user backspaces on a cell that's at the top of the screen, then the next cell above is non-existent
     as the tableview has not rendered it. Need to scroll that cell down into view before we do anything.
     And do this 2 rows in advance whenever possible, as the UI looks smoother that way.
     */
    guard let visibleRows = tableView.indexPathsForVisibleRows else { assertionFailure(); return }
    let nextNextIndexPath = IndexPath(row: max(index - 2, 0), section: itemsSection)
    if !visibleRows.contains(nextNextIndexPath) {
      UIView.animate(withDuration: 0.05, animations: {
        self.tableView.scrollToRow(at: nextNextIndexPath, at: .top, animated: true)
      }, completion: { success in
        // Wait until animation completes, otherwise, when user taps backspace lots and fast, we risk double-deleting stuff.
        if success {
          nextCellActionBlock()
        }
      })
    } else {
      nextCellActionBlock()
    }
  }
}

// MARK: - VoiceOver actions

/// Move Up / Down / to Top / to Bottom on every row, in and out of Reorder Items mode: neither the
/// drag handles nor the long-press drag can be used without dragging. Outside the mode, Duplicate
/// and Delete too: the swipe actions belong to the cell, which VoiceOver never lands on.
extension ChecklistViewController {
  func availableMoves(for item: Item) -> [ChecklistMoveAction] {
    let items = checklist.items
    // By identity: a row fading out after a delete still holds its item, whose properties are no
    // longer safe to read.
    guard let index = items.firstIndex(where: { $0 === item }) else { return [] }
    return ChecklistMoveAction.allCases.filter { $0.destination(from: index, count: items.count) != nil }
  }

  /// Moves the item with this id, then puts VoiceOver back on it and says where it landed. Reports
  /// whether it moved; a failed save has already been reported by `saveChanges`.
  @discardableResult
  func move(itemWithID id: String, _ action: ChecklistMoveAction) -> Bool {
    view.endEditing(true)
    let items = checklist.items
    let count = items.count
    guard let index = items.firstIndex(where: { $0.id == id }),
          let destination = action.destination(from: index, count: count),
          // Nothing has moved on screen yet, so a failure leaves nothing to put back.
          saveMove(of: items[index], among: items, to: destination)
    else { return false }

    let destinationIndexPath = IndexPath(row: destination, section: itemsSection)
    tableView.moveRow(at: IndexPath(row: index, section: itemsSection), to: destinationIndexPath)
    tableView.scrollToRow(at: destinationIndexPath, at: .none, animated: false)
    tableView.layoutIfNeeded()
    refreshAccessibilityActions()

    postAccessibilityFeedback(
      focus: rowFocusTarget(at: destination),
      announcement: Self.movedToPositionAnnouncement(position: destination + 1, count: count),
    )
    return true
  }

  /// Moves VoiceOver to `focus`, when there is one, then speaks `announcement`. Neither shows when
  /// VoiceOver is off.
  func postAccessibilityFeedback(focus: NSObject?, announcement: String?, afterMenu: Bool = false) {
    if let accessibilityFeedback {
      accessibilityFeedback(focus, announcement)
      return
    }
    Task {
      // From a row's context menu: waits for the menu to close, since the system moves VoiceOver
      // itself as it does, as ChecklistsView's `afterAlert` does.
      if afterMenu {
        try? await Task.sleep(for: .milliseconds(500))
      }
      // A turn later, so a swipe or custom action that triggered this has finished first: VoiceOver
      // re-seats its cursor when the element that ran the action goes away.
      if let focus {
        UIAccessibility.post(notification: .layoutChanged, argument: focus)
      }
      guard let announcement else { return }
      // Posted after a beat, or VoiceOver reading the refocused element cuts it off.
      try? await Task.sleep(for: .milliseconds(500))
      UIAccessibility.post(notification: .announcement, argument: announcement)
    }
  }

  /// The element VoiceOver lands on for the row at `index`, when that row is on screen.
  func rowFocusTarget(at index: Int) -> UIView? {
    (tableView.cellForRow(at: IndexPath(row: index, section: itemsSection)) as? ItemTableViewCell)?
      .itemContentView.accessibilityFocusTarget
  }

  /// Where VoiceOver goes once rows are gone: the row at `index`, or the Add button when no rows are
  /// left. Never scrolls, so nothing changes on screen when VoiceOver is off; a row off screen gets
  /// no focus, and VoiceOver stays where it puts itself.
  func focusTargetAfterRemoval(neighbour index: Int?) -> UIView? {
    tableView.layoutIfNeeded()
    guard let index else { return (tableView.tableFooterView as? AddItemButtonTableFooterView)?.addButton }
    return rowFocusTarget(at: index)
  }

  /// Built per row from the item, not its index path, so it reads the saved order even in the
  /// middle of a table update. Each action looks its item up again when it fires.
  private func accessibilityActions(for item: Item) -> [UIAccessibilityCustomAction] {
    // By identity, as in `availableMoves`: a row fading out after a delete gets no actions, and
    // its item's properties are no longer safe to read.
    guard checklist.items.contains(where: { $0 === item }) else { return [] }
    let id = item.id
    let moves = availableMoves(for: item).map { action in
      UIAccessibilityCustomAction(name: Self.moveActionTitle(for: action)) { [weak self] _ in
        self?.move(itemWithID: id, action) ?? false
      }
    }
    guard !isReordering else { return moves }
    // In the swipe actions' order, Delete outermost.
    return moves + [
      UIAccessibilityCustomAction(name: CommonStrings.duplicate) { [weak self] _ in
        guard let self, let index = checklist.items.firstIndex(where: { $0.id == id }) else { return false }
        duplicateItem(at: index)
        return true
      },
      UIAccessibilityCustomAction(name: CommonStrings.delete) { [weak self] _ in
        guard let self, let index = checklist.items.firstIndex(where: { $0.id == id }) else { return false }
        deleteItem(at: index, announcesResult: true)
        return true
      },
    ]
  }

  /// Which moves a row offers depends on where it sits, and Delete and Duplicate on the mode, so
  /// any change to the order, the count or the mode refreshes every row on screen. Rows scrolled in later get theirs from `cellForRowAt`.
  func refreshAccessibilityActions() {
    // Some suites drive the move callbacks without loading the view, so there is no table yet.
    guard isViewLoaded else { return }
    for case let cell as ItemTableViewCell in tableView.visibleCells {
      guard let item = cell.itemContentView.item else { continue }
      cell.itemContentView.setAccessibilityActions(accessibilityActions(for: item))
    }
  }
}
