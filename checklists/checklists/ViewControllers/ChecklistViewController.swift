//
//  ChecklistViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 6/8/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

private let itemsSection = 0
private let itemCellReuseIdentifier = "ItemCell"
private let defaultChecklistName = "Checklist"

protocol ChecklistViewControllerDelegate: class {
  func didDismissChecklistViewController(_ ChecklistViewController: ChecklistViewController)
}

/*
 Discussion about UITableViewController:
 Had to ditch it because the keyboard dynamics weren't working. The two main issues:
 1. When the user tapped to edit a field and quickly started typing, it would halt the animation to move the cell above the keyboard.
 2. When the list is super-long with lots of notes, the entire tableView would jitter up and down very quickly and/or
    have the wrong contentOffset.
 For some reason, when I implement manually with a couple slightly different coding things, this is all fixed. Urgghh...
 */
class ChecklistViewController: UIViewController {
  @IBOutlet var tableView: UITableView!
  var checklist: Checklist! // Expected to be set on seque or right after init(). Behavior undefined if this is set/reset after viewDidLoad().

  weak var delegate: ChecklistViewControllerDelegate?

  @IBOutlet weak var checklistInfoHeaderView: UIView!
  @IBOutlet weak var checklistNameTextField: UITextField!
  @IBOutlet weak var checklistNotesTextView: CLTextView!

  var isNewChecklist: Bool = false
  var isJumpingToFirstItem: Bool = false
  var isResetting: Bool = false

  // For drag/reorder of cells.
  private var snapshotView: UIView = UIView()
  private var sourceIndexPath: IndexPath = IndexPath(row: 0, section: 0)

  override func viewDidLoad() {
    super.viewDidLoad()

    NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardAppear(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardDisappear(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

    tableView.delegate = self
    tableView.dataSource = self

    tableView.dragInteractionEnabled = true
    tableView.dragDelegate = self
    tableView.dropDelegate = self

    tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: itemCellReuseIdentifier)

    checklistNameTextField.delegate = self
    checklistNotesTextView.delegate = self

    checklistNameTextField.text = checklist.name
    checklistNotesTextView.text = checklist.notes

    checklistNameTextField.accessibilityLabel = "Checklist Name: "
    checklistNotesTextView.accessibilityLabel = "Checklist Notes: "

    checklistNotesTextView.inputAccessoryButtonTappedAction = { [weak self] in
      self?.checklistNotesTextView.resignFirstResponder()
    }

    let tableFooterView = AddItemButtonTableFooterView(frame: .zero)
    tableFooterView.delegate = self
    tableView.tableFooterView = tableFooterView

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
    if checklist.items.count == 0 {
      let item = Item(name: "", notes: nil)
      DBManager.write {
        checklist.items.append(item)
      }
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if isNewChecklist {
      isNewChecklist = false // safeguard against future times viewWillAppear/viewDidAppear might get called.
      isJumpingToFirstItem = true
      checklistNameTextField.becomeFirstResponder()
    } else {
      self.tableView.flashScrollIndicators()
    }
    AnalyticsManager.logChecklistViewed(checklistName: checklist.name,
                                        checklistNotesLength: checklist.notes?.count ?? 0,
                                        numItems: checklist.items.count,
                                        numItemsWithNotes: checklist.items.filter({ $0.notes != nil && $0.notes!.count > 0 }).count)
  }

  override func viewWillDisappear(_ animated: Bool) {
    navigationController?.navigationBar.shadowImage = UIImage() // Architecturally not sustainable if we have more pages like this.
    super.viewWillDisappear(animated)
  }

  override func viewDidDisappear(_ animated: Bool) {
    DBManager.write {
      checklist.items.forEach { item in
        if item.name.count == 0 && (item.notes == nil || item.notes!.count == 0) {
          DBManager.realm.delete(item)
        }
      }
    }
    delegate?.didDismissChecklistViewController(self)
    super.viewDidDisappear(animated)
  }

  @objc func doneButtonTapped() {
    dismiss(animated: true, completion: nil)
  }

  @objc func resetButtonTapped() {
    AnalyticsManager.logResetChecklist()
    DBManager.write {
      checklist.items.forEach { item in
        item.status = .unchecked
      }
    }
    if tableView.contentOffset.y == 0.0 {
      self.tableView.reloadData()
    } else {
      isResetting = true
      self.scrollToTop()
    }
  }

  private func scrollToTop() {
    tableView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: true)
  }

  private func insertNewItem(becomeFirstResponder: Bool) {
    insertNewItem(at: checklist.items.count, becomeFirstResponder: becomeFirstResponder)
  }

  private func insertNewItem(at index: Int, becomeFirstResponder: Bool) {
    let item = Item(name: "", notes: nil)
    DBManager.write {
      self.checklist.items.insert(item, at: index)
    }

    let updates = {
      self.tableView.performBatchUpdates({
        self.collapseEditingCellIfNecessary()
        self.tableView.insertRows(at: [IndexPath(row: index, section: itemsSection)], with: .top)
      }, completion: nil)
    }

    let startEditingBlock: ((Bool) -> ()) = { success in
      if success {
        /*
         So, even though I do wait until completion of animation, when I don't have the async delay,
         for very long lists, for some reason, it doesn't scroll up the table view when the keyboard comes up.
         In shorter lists, it works fine, medium-ish lists are intermittent. So, by adding 5 ms and doing it async,
         it's as if I'm giving the table view a chance to gather itself and get situated before I startEditing().
         That's not a great explanation, but this is what it is as of iOS 13.
         */
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.005, execute: {
          guard let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: itemsSection)) as? ItemTableViewCell else { assertionFailure(); return }
          cell.itemContentView.startEditing()
        })
      }
    }
    /*
     This just isn't about making the animation snappier. If we're slow, and the user starts typing right after hitting Return,
     the letters go into the prior cell, not the new one, and there isn't an easy way to prevent that while keeping the animation
     smooth except to go faster. For example, I could resignFirstResponder() immediately, but then the keyboard drops and comes
     back up super fast, which makes it feel jittery.
     */
    UIView.animate(withDuration: 0.01, animations: updates, completion: becomeFirstResponder ? startEditingBlock : nil)
  }

  private func collapseEditingCellIfNecessary() {
    tableView.visibleCells.forEach { cell in
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
    checklist.remove(at: index)
    tableView.deleteRows(at: [IndexPath(item: index, section: itemsSection)], with: .fade)
  }
}

extension ChecklistViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return checklist.items.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    assert(indexPath.row >= 0 && indexPath.row < checklist.items.count && indexPath.section == itemsSection)
    guard let cell = tableView.dequeueReusableCell(withIdentifier: itemCellReuseIdentifier, for: indexPath) as? ItemTableViewCell else { assertionFailure(); return UITableViewCell() }
    cell.itemContentView.item = checklist.items[indexPath.row]
    cell.itemContentView.delegate = self
    return cell
  }

  func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    guard indexPath.section == itemsSection else { assertionFailure(); return false }
    return true
  }

  func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    checklist.moveItem(from: sourceIndexPath.row, to: destinationIndexPath.row)
  }
}

extension ChecklistViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    guard indexPath.section == itemsSection else { assertionFailure(); return }
    if editingStyle == .delete {
      deleteItem(at: indexPath.row)
    } else if editingStyle == .insert {
      assertionFailure()
    }
  }

  func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
    return false
  }

  func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
    guard indexPath.section == itemsSection else { assertionFailure(); return .none }
    return .delete
  }
}

extension ChecklistViewController: UIScrollViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let currentY: CGFloat = scrollView.contentOffset.y
    let thresholdY: CGFloat = 52.0

    if isResetting == true && currentY == 0.0 {
      isResetting = false
      self.tableView.reloadData()
    }
    if currentY <= thresholdY && navigationItem.title != nil {
      UIView.animate(withDuration: 0.4, animations: {
        self.navigationItem.title = nil
        self.navigationController?.navigationBar.shadowImage = UIImage()
      })
    }
    if currentY > thresholdY && navigationItem.title == nil {
      UIView.animate(withDuration: 0.4, animations: {
        self.navigationItem.title = self.checklist.name
        self.navigationController?.navigationBar.shadowImage = nil
      })
    }
  }
}

// MARK: - Keyboard dynamics.
// https://developer.apple.com/library/archive/documentation/StringsTextFonts/Conceptual/TextAndWebiPhoneOS/KeyboardManagement/KeyboardManagement.html
extension ChecklistViewController {
  @objc func onKeyboardAppear(_ notification: NSNotification) {
    guard
      let userInfo = notification.userInfo,
      let keyboardHeight = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.size.height
      else { assertionFailure(); return }

    guard let cell = findEditingCell() else { return } // If keyboard arose for Checklist Name/Notes, which, if visible, shouldn't require scrolling (except for massive notes, but we're accepting that for now).

    var visibleFrame = tableView.frame
    visibleFrame.size.height = visibleFrame.size.height - keyboardHeight

    // Conversion is unnecessary, as Cell's superview is actually tableView in iOS 12, but paranoid future-proofing.
    let cellFrame = tableView.convert(cell.frame, from: cell.superview)

    if !visibleFrame.contains(cellFrame) { // If even partially covered, move it.
      let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardHeight, right: 0.0)
      // iOS 12: If user taps to edit, and then quickly starts typing, it halts the animation to scroll the cell above
      // the keyboard if using the default scrollRectToVisible with animated=true, so need this animation block. Also, snappier.
      UIView.animate(withDuration: 0.1) {
        self.tableView.contentInset = contentInsets
        self.tableView.scrollIndicatorInsets = contentInsets
        self.tableView.scrollRectToVisible(cellFrame, animated: false)
        // Known issue: As of iOS 12, when animated = false, on ONLY THE SIMULATOR, it scrolls just one cell too much. Weird.
        // Doesn't happen when animated = true, but then the animation is too slow and when user types quickly after tapping to edit,
        // the animation halts.
      }
    }
  }

  @objc func onKeyboardDisappear(_ notification: NSNotification) {
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

// For the Checklist Name field.
extension ChecklistViewController: UITextFieldDelegate {
  func textFieldDidBeginEditing(_ textField: UITextField) {
    if textField.hasText {
      isJumpingToFirstItem = false // Handling odd use case.
    }
  }
  func textFieldDidEndEditing(_ textField: UITextField) {
    DBManager.write {
      checklist.name = checklistNameTextField.hasText ? checklistNameTextField.text ?? defaultChecklistName : defaultChecklistName // Accounts for both nil and empty string.
    }
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

// For the Checklist Notes field.
extension ChecklistViewController: UITextViewDelegate {
  func textViewDidEndEditing(_ textView: UITextView) {
    DBManager.write {
      checklist.notes = checklistNotesTextView.text
    }
  }
  func textViewDidChange(_ textView: UITextView) {
    // According to StackOverflow, this seems to be the accepted-yet-janky way of pushing the cells down as the header expands.
    tableView.setNeedsLayout()
    tableView.layoutIfNeeded()
    tableView.tableHeaderView = self.checklistInfoHeaderView
  }
}

extension ChecklistViewController: AddItemButtonTableFooterViewDelegate {
  func addItemTableViewCellTapped() {
    insertNewItem(becomeFirstResponder: true)
  }
}

// MARK: - Drag/Drop Reorder

extension ChecklistViewController: UITableViewDragDelegate  {
  func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
    guard indexPath.section == itemsSection, indexPath.row < checklist.items.count else { assertionFailure(); return [] }
    return checklist.items[indexPath.row].dragItems()
  }
}

extension ChecklistViewController: UITableViewDropDelegate {
  func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
    return session.canLoadObjects(ofClass: NSString.self)
  }

  func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
    if tableView.hasActiveDrag {
      if session.items.count > 1 {
        return UITableViewDropProposal(operation: .cancel)
      } else {
        return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
      }
    } else { // dropped from external to app
      return UITableViewDropProposal(operation: .cancel)
    }
  }

  func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
    let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(row: checklist.items.count, section: itemsSection)
    assert(coordinator.items.count == 1)
    guard let dropItem = coordinator.items.first else { assertionFailure(); return }
    let itemProvider = dropItem.dragItem.itemProvider
    itemProvider.loadObject(ofClass: NSString.self) { string, error in
      if let itemId = string as? String {
        if let sourceIndex = self.checklist.items.firstIndex(where: { item in return item.id == itemId }) {
          self.checklist.moveItem(from: sourceIndex, to: destinationIndexPath.row)
          DispatchQueue.main.async {
            tableView.moveRow(at: IndexPath(row: sourceIndex, section: destinationIndexPath.section), to: destinationIndexPath)
          }
        }
      }
    }
  }
}

// MARK: - ItemContentViewDelegate - responding to cell events.

/*
 This is architecturally questionable, as I'm passing the Item back from the ItemContentView to update
 the database as opposed to looking it up, but it's convenient right now. In a true MVVM
 model this wouldn't be possible.
 */
extension ChecklistViewController: ItemContentViewDelegate {
  func itemContentViewDidFinishEditing(_ itemContentView: ItemContentView) {
    cellHeightRequiresRefresh(animated: true)
  }

  func itemContentViewCheckboxButtonTapped(_ itemContentView: ItemContentView) {
    DBManager.write {
      let item = itemContentView.item
      item?.toggleStatus()
      itemContentView.item = item // Re-render after toggle.
    }
  }

  func itemContentViewNameFieldDidBeginEditing(_ itemContentView: ItemContentView) {
    itemContentView.updateTextViewHeight(isExpanded: true)
    cellHeightRequiresRefresh(animated: true)
  }

  func itemContentViewHeightUpdated(_ itemContentView: ItemContentView) {
    // Don't animate, or stuff gets jittery when table view is scrolled up and user is typing in text view.
    cellHeightRequiresRefresh(animated: false)
  }

  func itemContentView(_ itemContentView: ItemContentView, nameFieldUpdatedWith name: String) {
    DBManager.write {
      itemContentView.item?.name = name
    }
  }

  func itemContentView(_ itemContentView: ItemContentView, notesFieldUpdatedWith notes: String) {
    DBManager.write {
      itemContentView.item?.notes = notes
    }
  }

  func itemContentViewDidReturnOnNameField(_ itemContentView: ItemContentView) {
    guard
      let item = itemContentView.item,
      let index = checklist.items.index(of: item)
      else { assertionFailure(); return }
    insertNewItem(at: index + 1, becomeFirstResponder: true)
  }

  func itemContentViewDidBackspaceEmpty(_ itemContentView: ItemContentView) {
    guard
      let item = itemContentView.item,
      let index = checklist.items.index(of: item)
      else { assertionFailure(); return }
    if index > 0 { // Nothing happens if backspaced on first item in list.
      guard let cell = tableView.cellForRow(at: IndexPath(item: index - 1, section: itemsSection)) as? ItemTableViewCell else { assertionFailure(); return }
      cell.itemContentView.startEditing()
      deleteItem(at: index)
    }
  }
}
