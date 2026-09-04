//
//  ChecklistViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 6/8/19.
//

import SwiftData
import UIKit

private let itemsSection = 0
private let itemCellReuseIdentifier = "ItemCell"
private let defaultChecklistName = "untitled checklist"

protocol ChecklistViewControllerDelegate: AnyObject {
  func willDismissChecklistViewController(_ checklistViewController: ChecklistViewController)
}

/**
 Discussion about UITableViewController:
 Had to ditch it because the keyboard dynamics weren't working. The two main issues:
 1. When the user tapped to edit a field and quickly started typing, it would halt the animation to move the cell above the keyboard.
 2. When the list is super-long with lots of notes, the entire tableView would jitter up and down very quickly and/or
    have the wrong contentOffset.
 For some reason, when I implement manually with a couple slightly different coding things, this is all fixed. Urgghh...
 */
class ChecklistViewController: UIViewController {
  private var tableView: UITableView!
  var checklist: Checklist! // Expected to be set on seque or right after init(). Behavior undefined if this is set/reset after viewDidLoad().

  weak var delegate: ChecklistViewControllerDelegate?

  private let checklistInfoHeaderView = UIView()
  private let statusIcon = CircularPercentStatusIcon(iconType: .header)
  private let checklistNameTextField = CLTextField()
  private let checklistNotesTextView = CLTextView()

  private var remoteChangeObserver: RemoteChangeObserver?

  private var context: ModelContext {
    PersistenceController.shared.mainContext
  }

  var isNewChecklist: Bool = false
  var isJumpingToFirstItem: Bool = false
  var isResetting: Bool = false

  // For drag/reorder of cells.
  private var snapshotView: UIView = .init()
  private var sourceIndexPath: IndexPath = .init(row: 0, section: 0)

  override func loadView() {
    let tableView = UITableView(frame: .zero, style: .plain)
    self.tableView = tableView
    view = tableView
  }

  /// Reproduces the "Checklist" storyboard scene's tableHeaderView: a status icon, a name field, and a notes view.
  private func setUpHeaderView() {
    // Required for the width-anchor + layoutIfNeeded() sizing dance below to compute this view's natural
    // height from its subviews' constraints (mirrors a runtime attribute the old storyboard scene set explicitly).
    checklistInfoHeaderView.translatesAutoresizingMaskIntoConstraints = false
    checklistInfoHeaderView.backgroundColor = Colors.defaultBackground

    checklistNameTextField.delegate = self
    checklistNameTextField.placeholder = "Name"
    checklistNameTextField.font = .systemFont(ofSize: 24.0, weight: .semibold)
    checklistNameTextField.returnKeyType = .done
    checklistNameTextField.enablesReturnKeyAutomatically = true
    checklistNameTextField.clearButtonMode = .whileEditing
    checklistNameTextField.accessibilityIdentifier = "checklistNameField"
    checklistNameTextField.accessibilityLabel = "Checklist Name: "
    checklistNameTextField.text = checklist.name

    checklistNotesTextView.delegate = self
    checklistNotesTextView.font = .systemFont(ofSize: 16.0)
    checklistNotesTextView.backgroundColor = .clear
    checklistNotesTextView.placeholderText = "Notes"
    checklistNotesTextView.accessibilityIdentifier = "checklistNotesTextView"
    checklistNotesTextView.accessibilityLabel = "Checklist Notes: "
    checklistNotesTextView.text = checklist.notes

    checklistInfoHeaderView.addSubview(statusIcon)
    checklistInfoHeaderView.addSubview(checklistNameTextField)
    checklistInfoHeaderView.addSubview(checklistNotesTextView)
    statusIcon.translatesAutoresizingMaskIntoConstraints = false
    checklistNameTextField.translatesAutoresizingMaskIntoConstraints = false
    checklistNotesTextView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      statusIcon.leadingAnchor.constraint(equalTo: checklistInfoHeaderView.leadingAnchor, constant: 16.0),

      checklistNameTextField.topAnchor.constraint(equalTo: checklistInfoHeaderView.topAnchor, constant: 22.0),
      checklistNameTextField.leadingAnchor.constraint(equalTo: statusIcon.trailingAnchor, constant: 10.0),
      checklistNameTextField.trailingAnchor.constraint(equalTo: checklistInfoHeaderView.trailingAnchor, constant: -16.0),
      checklistNameTextField.centerYAnchor.constraint(equalTo: statusIcon.centerYAnchor),
      checklistNameTextField.heightAnchor.constraint(equalToConstant: 32.0),

      checklistNotesTextView.topAnchor.constraint(equalTo: checklistNameTextField.bottomAnchor, constant: 4.0),
      checklistNotesTextView.leadingAnchor.constraint(equalTo: checklistInfoHeaderView.layoutMarginsGuide.leadingAnchor, constant: 8.0),
      checklistNotesTextView.trailingAnchor.constraint(equalTo: checklistInfoHeaderView.trailingAnchor, constant: -16.0),
      checklistNotesTextView.bottomAnchor.constraint(equalTo: checklistInfoHeaderView.bottomAnchor, constant: -15.0),
      checklistNotesTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 32.0),
    ])
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
    tableView.sectionHeaderHeight = 28
    tableView.sectionFooterHeight = 28
    tableView.backgroundColor = Colors.defaultBackground

    setUpHeaderView()
    // Assign this early (before the width-anchor constraint below) so checklistInfoHeaderView shares an
    // ancestor with tableView — it's reassigned again after layout, once its frame height is known.
    tableView.tableHeaderView = checklistInfoHeaderView

    checklistNotesTextView.inputAccessoryButtonTappedAction = { [weak self] in
      self?.checklistNotesTextView.resignFirstResponder()
    }

    let tableFooterView = AddItemButtonTableFooterView(frame: .zero)
    tableFooterView.delegate = self
    tableView.tableFooterView = tableFooterView

    updateStatusIcon()

    //  Despite Apple docs saying the width is set, it is not (as of iOS 12), and StackOverflow seems to only show manual ways like this.
    checklistInfoHeaderView.widthAnchor.constraint(equalTo: tableView.widthAnchor, multiplier: 1.0).isActive = true
    tableFooterView.widthAnchor.constraint(equalTo: tableView.widthAnchor, multiplier: 1.0).isActive = true

    // If I don't call this, the header view's frame's height isn't set and an extensive Notes section will overlap the top of the cells.
    checklistInfoHeaderView.setNeedsLayout()
    checklistInfoHeaderView.layoutIfNeeded()
    /*
     Admittedly a bit hacky, as this is already in the view hierarchy in IB, but want to properly set it while
     not creating a separate xib file and custom UIView. This also adjusts the tableView for the newly calculated frame height.
     */
    tableView.tableHeaderView = checklistInfoHeaderView

    if isNewChecklist {
      navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
    } else {
      navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Reset", style: .plain, target: self, action: #selector(resetButtonTapped))
    }
    if checklist.items.isEmpty {
      try? context.insert(item: Item(), at: 0, in: checklist)
    }

    // Refreshes when another device's changes are merged in. Inert until CloudKit is switched on.
    remoteChangeObserver = RemoteChangeObserver { [weak self] in
      self?.handleRemoteChange()
    }
  }

  /// Reacts to this checklist being changed, or deleted, somewhere other than this screen.
  private func handleRemoteChange() {
    guard !checklist.isDeleted, context.checklist(id: checklist.id) != nil else {
      // Deleted on another device while open here. Leaving the screen up would let the user keep
      // editing a record that no longer exists.
      if let navigationController, navigationController.viewControllers.count > 1 {
        navigationController.popViewController(animated: true)
      } else {
        dismiss(animated: true)
      }
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
    updateStatusIcon()
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
    AnalyticsManager.logChecklistViewed(
      checklistName: checklist.name,
      checklistNotesLength: checklist.notes?.count ?? 0,
      numItems: checklist.items.count,
      numItemsWithNotes: checklist.items.count(where: { $0.notes != nil && !$0.notes!.isEmpty })
    )
  }

  override func viewWillDisappear(_ animated: Bool) {
    // If any field is still focused when the user backs out (e.g. tapped Back right after typing,
    // without tapping elsewhere first), its `resignFirstResponder`-triggered commit would otherwise
    // land late: resignation normally only happens once the view is actually removed from the window,
    // near the end of the pop transition. `endEditing(true)` forces it here instead, synchronously,
    // and covers the whole view — both the header fields and the item cells' text views — because
    // each of the two has its own ordering hazard:
    //
    //   - Header (checklistNameTextField/checklistNotesTextView): its commit
    //     (textFieldDidEndEditing/textViewDidEndEditing, below) has to land before the delegate's
    //     `reloadData()` on the next line, or the checklists list's cached cell preview keeps showing
    //     the pre-edit value until some unrelated reload happens to occur.
    //   - Item cells: their commit (ItemContentView's textViewDidEndEditing →
    //     `itemContentView(_:nameFieldUpdatedWith:)`) has to land before `viewDidDisappear`'s
    //     dangling-empty-item trim loop, which deletes trailing items whose name and notes are both
    //     empty. A name typed into the last item but not yet committed reads as empty to that loop, so
    //     the item gets deleted and the pending write then targets an invalidated Realm object.
    view.endEditing(true)
    delegate?.willDismissChecklistViewController(self)
    super.viewWillDisappear(animated)
  }

  override func viewDidDisappear(_ animated: Bool) {
    // If user left some 'dangling' empty items at end of list, remove them, but don't worry if there's one lone empty item.
    // Snapshotted up front: deleting from the context does not re-sort this array, so walking a
    // stale copy backwards is both correct and cheaper than recomputing the sorted items each step.
    let items = checklist.items
    var didDelete = false
    var i = items.count - 1
    while i > 0 {
      let item = items[i]
      if item.name.isEmpty, item.notes == nil || item.notes!.isEmpty {
        context.delete(item)
        didDelete = true
      } else {
        break
      }
      i -= 1
    }
    if didDelete {
      context.saveChangesIgnoringFailure(operation: .delete)
    }
    super.viewDidDisappear(animated)
  }

  @objc func doneButtonTapped() {
    dismiss(animated: true, completion: nil)
  }

  @objc func resetButtonTapped() {
    AnalyticsManager.logResetChecklist()

    checklist.uncheckAllItems()
    context.saveChangesIgnoringFailure(operation: .checklistEdit)
    updateStatusIcon()

    if tableView.contentOffset.y == 0.0 {
      tableView.reloadData()
    } else {
      isResetting = true
      scrollToTop()
    }
  }

  private func scrollToTop() {
    tableView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: true)
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
        // Added extra call below because of https://github.com/jimmynotjames/checklists/issues/97, where tapping Next,
        // it didn't scroll up to make the editable view visible. Make first responder should have been, fine,
        // but adding this explicit scroll makes it work much more reliably.
        self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        cell.itemContentView.startEditing()
      }
    }
    /*
     This just isn't about making the animation snappier. If we're slow, and the user starts typing right after hitting Return,
     the letters go into the prior cell, not the new one, and there isn't an easy way to prevent that while keeping the animation
     smooth except to go faster. For example, I could resignFirstResponder() immediately, but then the keyboard drops and comes
     back up super fast, which makes it feel jittery.
     */
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
    context.delete(items[index])
    context.saveChangesIgnoringFailure(operation: .delete)
    tableView.deleteRows(at: [IndexPath(item: index, section: itemsSection)], with: .fade)
    updateStatusIcon()
  }

  func updateStatusIcon() {
    statusIcon.percentageComplete = checklist.percentageComplete
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
    try? context.move(item: items[sourceIndexPath.row], among: items, to: destinationIndexPath.row)
  }
}

extension ChecklistViewController: UITableViewDelegate {
  func tableView(_: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    guard indexPath.section == itemsSection else { assertionFailure(); return }
    if editingStyle == .delete {
      deleteItem(at: indexPath.row)
    } else if editingStyle == .insert {
      assertionFailure()
    }
  }

  func tableView(_: UITableView, shouldHighlightRowAt _: IndexPath) -> Bool {
    false
  }

  func tableView(_: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
    guard indexPath.section == itemsSection else { assertionFailure(); return .none }
    return .delete
  }
}

extension ChecklistViewController: UIScrollViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let currentY: CGFloat = scrollView.contentOffset.y
    let thresholdY: CGFloat = 52.0

    if isResetting == true, currentY == 0.0 {
      isResetting = false
      tableView.reloadData()
    }
    if currentY <= thresholdY, navigationItem.title != nil {
      UIView.animate(withDuration: 0.4, animations: {
        self.navigationItem.title = nil
      })
    }
    if currentY > thresholdY, navigationItem.title == nil {
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

    var visibleFrame = tableView.frame
    visibleFrame.size.height -= keyboardHeight

    // Conversion is unnecessary, as Cell's superview is actually tableView in iOS 12, but paranoid future-proofing.
    let cellFrame = tableView.convert(cell.frame, from: cell.superview)

    let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardHeight, right: 0.0)
    // iOS 12: If user taps to edit, and then quickly starts typing, it halts the animation to scroll the cell above
    // the keyboard if using the default scrollRectToVisible with animated=true, so need this animation block. Also, snappier.
    UIView.animate(withDuration: 0.1) {
      self.tableView.contentInset = contentInsets
      self.tableView.scrollIndicatorInsets = contentInsets
      if !visibleFrame.contains(cellFrame) { // If even partially covered, move it.
        self.tableView.scrollRectToVisible(cellFrame, animated: false)
        // Known issue: As of iOS 12, when animated = false, on ONLY THE SIMULATOR, it scrolls just one cell too much. Weird.
        // Doesn't happen when animated = true, but then the animation is too slow and when user types quickly after tapping to edit,
        // the animation halts.
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
    checklist.name = checklistNameTextField.hasText ? checklistNameTextField.text ?? defaultChecklistName : defaultChecklistName // Accounts for both nil and empty string.
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
    // According to StackOverflow, this seems to be the accepted-yet-janky way of pushing the cells down as the header expands.
    tableView.setNeedsLayout()
    tableView.layoutIfNeeded()
    tableView.tableHeaderView = checklistInfoHeaderView
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
        try? self.context.move(item: items[sourceIndex], among: items, to: destinationIndexPath.row)
        tableView.moveRow(at: IndexPath(row: sourceIndex, section: destinationIndexPath.section), to: destinationIndexPath)
      }
    }
  }
}

// MARK: - ItemContentViewDelegate - responding to cell events.

/**
 This is architecturally questionable, as I'm passing the Item back from the ItemContentView to update
 the database as opposed to looking it up, but it's convenient right now. In a true MVVM
 model this wouldn't be possible.
 */
extension ChecklistViewController: ItemContentViewDelegate {
  func itemContentViewDidFinishEditing(_: ItemContentView) {
    cellHeightRequiresRefresh(animated: true)
  }

  func itemContentViewCheckboxButtonTapped(_ itemContentView: ItemContentView) {
    itemContentView.item?.toggleStatus()
    context.saveChangesIgnoringFailure(operation: .itemEdit)
    itemContentView.updateCheckedStatus()
    updateStatusIcon()
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
