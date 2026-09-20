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
  /// SwiftUI-presented container would leave the router's sheet/path out of sync with what's on
  /// screen. When unset (pure-UIKit presentation), the original dismiss/pop paths still run.
  var onRequestDismiss: (() -> Void)?

  /// Set by the SwiftUI host (`ChecklistScreen`). Called with the new checklist's `id` after a
  /// duplication, for the host to present. The id rather than the model, like every other
  /// cross-screen reference in the app (see `AppRoute`); the controller has no router and should
  /// not acquire one. Unset (pure-UIKit presentation, previews, tests) means the copy is still
  /// made and saved, just not opened.
  var onRequestOpenDuplicate: ((String) -> Void)?

  /// Set by the SwiftUI host (`ChecklistScreen`), like `onRequestDismiss` above. There is no
  /// environment to read from here, so the client is pushed in. The console default keeps
  /// pure-UIKit construction and previews working without any setup, and means a missed
  /// injection degrades to "no events" rather than a crash.
  var analytics: any AnalyticsClient = ConsoleAnalyticsClient()

  /// Set by the SwiftUI host, like `analytics` above. Fed one call per item checked off — the
  /// qualifying action for the automatic App Store review prompt. `nil` (pure-UIKit construction,
  /// previews, tests) means the prompt is simply never fed.
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

  /// How far down the list must be dragged before an in-progress edit is committed.
  private let keyboardDismissDragThreshold: CGFloat = 40.0

  /// Internal rather than private so `ChecklistViewController+Menu` can reach it.
  var context: ModelContext {
    PersistenceController.shared.mainContext
  }

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

  /// Writes an item's new position to the store.
  ///
  /// A closure rather than a direct call so tests can drive the failure path: a real SwiftData save
  /// only fails on a full or damaged disk, which a test has no way to arrange.
  var saveItemMove: (Item, [Item], Int) throws -> Void = { item, siblings, index in
    try PersistenceController.shared.mainContext.move(item: item, among: siblings, to: index)
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
    NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardDisappear(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

    tableView.accessibilityIdentifier = "ChecklistTableView"
    tableView.delegate = self
    tableView.dataSource = self

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

    checklistNotesTextView.inputAccessoryButtonTappedAction = { [weak self] in
      self?.checklistNotesTextView.resignFirstResponder()
    }

    let tableFooterView = AddItemButtonTableFooterView(frame: .zero)
    tableFooterView.delegate = self
    tableView.tableFooterView = tableFooterView

    updateStatusIcon()

    // The footer's width isn't set automatically despite the docs; set it manually.
    tableFooterView.widthAnchor.constraint(equalTo: tableView.widthAnchor, multiplier: 1.0).isActive = true

    configureNavigationBar()
    if checklist.items.isEmpty {
      try? context.insert(item: Item(), at: 0, in: checklist)
    }

    // Refreshes when another device's changes are merged in via CloudKit sync.
    remoteChangeObserver = RemoteChangeObserver { [weak self] in
      self?.handleRemoteChange()
    }
  }

  /// Reacts to this checklist being changed, or deleted, somewhere other than this screen.
  private func handleRemoteChange() {
    guard !checklist.isDeleted, context.checklist(id: checklist.id) != nil else {
      // Deleted on another device while open here. Leaving the screen up would let the user keep
      // editing a record that no longer exists.
      requestDismissal()
      return
    }

    // Never yank the table out from under an active edit; the merged values are already in the
    // model and will show on the next natural reload.
    guard findEditingCell() == nil,
          !checklistNameTextField.isFirstResponder,
          !checklistNotesTextView.isFirstResponder
    else { return }

    checklistNameTextField.text = checklist.name
    checklistNotesTextView.text = checklist.notes
    // Notes from another device can be any length.
    headerContentDidChange()
    updateStatusIcon()
    // Cheap now the caption is a fixed height: another device's tick shows up without a reopen.
    refreshHistoryCaption()
    tableView.reloadData()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if isNewChecklist {
      isNewChecklist = false // safeguard against future times viewWillAppear/viewDidAppear might get called.
      isJumpingToFirstItem = true
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

  @objc func doneButtonTapped() {
    if let onRequestDismiss {
      onRequestDismiss()
    } else {
      dismiss(animated: true, completion: nil)
    }
  }

  @objc func resetButtonTapped() {
    analytics.track(AnalyticsEvent.checklistReset)

    // Nothing ticked means nothing to update: a Reset on an untouched list must not date it.
    let wasComplete = checklist.isComplete
    if checklist.uncheckAllItems() {
      context.saveStatusChange(to: checklist, wasComplete: wasComplete)
      refreshHistoryCaption()
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
  /// under the navigation bar the top is the negative of the adjusted inset (#145).
  private var topContentOffset: CGPoint {
    CGPoint(x: 0.0, y: -tableView.adjustedContentInset.top)
  }

  /// Whether a scroll view is resting at its top, inset included.
  ///
  /// Static and internal so tests can drive it without loading the view — loading it reaches
  /// `PersistenceController.shared`, which is not installed in the test target.
  static func isAtTop(_ scrollView: UIScrollView) -> Bool {
    scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + atTopTolerance
  }

  private func scrollToTop() {
    tableView.setContentOffset(topContentOffset, animated: true)
  }

  private func insertNewItem(becomeFirstResponder: Bool) {
    insertNewItem(at: checklist.items.count, becomeFirstResponder: becomeFirstResponder)
  }

  private func insertNewItem(at index: Int, becomeFirstResponder: Bool) {
    do {
      try context.insert(item: Item(), at: index, in: checklist)
    } catch {
      return // Already logged and reported by `saveChanges`; nothing was inserted.
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
        // Explicit scroll needed: becomeFirstResponder alone doesn't reliably scroll the new row into view (#97).
        self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        cell.itemContentView.startEditing()
      }
    }
    // Duration matters for correctness, not just polish: too slow and fast-typing-after-Return
    // sends the letters into the prior cell instead of the new one.
    UIView.animate(withDuration: 0.01, animations: updates, completion: becomeFirstResponder ? startEditingBlock : nil)

    updateStatusIcon()
  }

  private func collapseEditingCellIfNecessary() {
    for cell in tableView.visibleCells {
      if let cell = cell as? ItemTableViewCell, cell.itemContentView.isEditing {
        cell.itemContentView.refreshHeight()
      }
    }
  }

  func cellHeightRequiresRefresh(animated: Bool) {
    if !animated {
      UIView.setAnimationsEnabled(false) // When table view is scrolled up a bit and user types in text view, jitters without this.
    }
    tableView.beginUpdates()
    tableView.endUpdates()
    if !animated {
      UIView.setAnimationsEnabled(true)
    }
  }

  func deleteItem(at index: Int) {
    let items = checklist.items
    guard index >= 0, index < items.count else { assertionFailure(); return }
    let wasComplete = checklist.isComplete
    context.delete(items[index])
    context.saveDeletion(from: checklist, wasComplete: wasComplete)
    tableView.deleteRows(at: [IndexPath(item: index, section: itemsSection)], with: .fade)
    updateStatusIcon()
    refreshHistoryCaption()
  }

  /// Copies the item at `index` and places the copy directly beneath it. See
  /// `ModelContext.duplicate(item:in:)` — unlike checklist duplication, the name carries over
  /// unchanged.
  func duplicateItem(at index: Int) {
    // Commits any in-progress edit first, or the copy would be taken from stale, uncommitted
    // text — the same reason `duplicateChecklist()` ends editing before copying.
    view.endEditing(true)
    let items = checklist.items
    guard index >= 0, index < items.count else { assertionFailure(); return }
    guard (try? context.duplicate(item: items[index], in: checklist)) != nil else { return }
    tableView.insertRows(at: [IndexPath(row: index + 1, section: itemsSection)], with: .automatic)
    // Not a status change: no timestamp write, no history-caption refresh — matches
    // `insertNewItem`. The new unchecked row can still move `percentageComplete` and flip
    // `isComplete`, which is why the status icon alone needs a refresh.
    updateStatusIcon()
  }

  /// The width the header was last measured against. `view` is the table itself, so this runs on
  /// every scroll frame — and measuring means a full layout plus TextKit pass over the notes.
  private var lastHeaderWidth: CGFloat = 0.0

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
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
      try saveItemMove(item, siblings, index)
      return true
    } catch {
      return false
    }
  }

  /// Ends editing when the list is dragged down far enough to mean it.
  ///
  /// Overridden in tests to observe the dismissal without loading the view.
  func endEditingAfterDragDismiss() {
    view.endEditing(true)
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
  }
}

extension ChecklistViewController: UITableViewDelegate {
  func tableView(_: UITableView, shouldHighlightRowAt _: IndexPath) -> Bool {
    false
  }

  /// Delete keeps the outermost slot and the full-swipe gesture; Duplicate sits beside it,
  /// matching the list screen's ordering (`ChecklistsView.swift`).
  func tableView(_: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard indexPath.section == itemsSection, indexPath.row < checklist.items.count else { assertionFailure(); return nil }

    let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
      self?.deleteItem(at: indexPath.row)
      completion(true)
    }
    deleteAction.image = UIImage(systemName: "trash")
    deleteAction.backgroundColor = Colors.destructive
    deleteAction.accessibilityLabel = CommonStrings.delete

    let duplicateAction = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, completion in
      self?.duplicateItem(at: indexPath.row)
      completion(true)
    }
    duplicateAction.image = UIImage(systemName: "plus.square.on.square")
    duplicateAction.backgroundColor = Colors.accent
    duplicateAction.accessibilityLabel = CommonStrings.duplicate

    let configuration = UISwipeActionsConfiguration(actions: [deleteAction, duplicateAction])
    configuration.performsFirstActionWithFullSwipe = true
    return configuration
  }
}

extension ChecklistViewController: UIScrollViewDelegate {
  /// Drag-to-dismiss. `keyboardDismissMode` is the stock way to get this, but on iOS 26 both
  /// `.onDragWithAccessory` and `.interactiveWithAccessory` hide the keyboard without resigning the
  /// field, which strands the Done accessory at the bottom of the screen.
  ///
  /// Only a deliberate downward drag counts, so scrolling up to read the rest of the list leaves an
  /// edit in progress alone.
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    if scrollView.isDragging, scrollView.panGestureRecognizer.translation(in: scrollView).y > keyboardDismissDragThreshold {
      endEditingAfterDragDismiss()
    }
    // Measured from the table's real top rather than a literal zero, so the threshold below means
    // the distance actually scrolled: `52.0` clears the name field, which sits at 22-54 in the
    // header (#145).
    let scrolledY: CGFloat = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    let thresholdY: CGFloat = 52.0

    if isResetting == true, Self.isAtTop(scrollView) {
      isResetting = false
      tableView.reloadData()
    }
    if scrolledY <= thresholdY, navigationItem.title != nil {
      UIView.animate(withDuration: 0.4, animations: {
        self.navigationItem.title = nil
      })
    }
    if scrolledY > thresholdY, navigationItem.title == nil {
      UIView.animate(withDuration: 0.4, animations: {
        self.navigationItem.title = self.checklist.name
      })
    }
  }
}

// MARK: - Keyboard dynamics.

/// https://developer.apple.com/library/archive/documentation/StringsTextFonts/Conceptual/TextAndWebiPhoneOS/KeyboardManagement/KeyboardManagement.html
extension ChecklistViewController {
  @objc func onKeyboardAppear(_ notification: NSNotification) {
    guard
      let userInfo = notification.userInfo,
      var keyboardHeight = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.size.height
    else { assertionFailure(); return }

    guard let cell = findEditingCell()
    else { return } // If keyboard arose for Checklist Name/Notes, which, if visible, shouldn't require scrolling (except for massive notes, but we're accepting that for now).

    keyboardHeight += 20.0 // On iPhone 8-style resolutions, it doesn't scroll up quite enough, so adding this in, even though iPhone X-style goes up a tad more than I'd like.

    // `cell.frame` below is in the table's content space; `tableView.frame` is in its superview's,
    // and the two only line up at a content offset of zero (#145). `bounds` is content space, so
    // inset it by the bar above and the keyboard below to get the genuinely visible slice.
    let visibleFrame = tableView.bounds.inset(by: UIEdgeInsets(
      top: tableView.adjustedContentInset.top,
      left: 0.0,
      bottom: keyboardHeight,
      right: 0.0
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

  private func findEditingCell() -> UITableViewCell? {
    for cell in tableView.visibleCells {
      if let cell = cell as? ItemTableViewCell, cell.itemContentView.isEditing {
        return cell
      }
    }
    return nil
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
    // drags below the bottom of the list). The clamp to `count - 1` (the last valid index) is still
    // required, but the reason has moved: the sort-key reorder below handles one-past-the-end fine
    // — it just appends — whereas `tableView.moveRow` would be given an out-of-range index path.
    // Clamping keeps both agreeing that the drop means "move to the end."
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
    guard let item = itemContentView.item else { return }
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

  func itemContentViewHeightUpdated(_: ItemContentView) {
    // Don't animate, or stuff gets jittery when table view is scrolled up and user is typing in text view.
    cellHeightRequiresRefresh(animated: false)
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
        // Wait until animation completes, otherwise, when user taps backspace lots and fast, we get crashes from Realm due to double-deleting stuff.
        if success {
          nextCellActionBlock()
        }
      })
    } else {
      nextCellActionBlock()
    }
  }
}
