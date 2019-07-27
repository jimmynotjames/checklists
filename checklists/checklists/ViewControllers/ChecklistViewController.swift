//
//  ChecklistViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 6/8/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit
import GrowingTextView

private let itemsSection = 0
private let itemCellReuseIdentifier = "ItemCell"
private let AddItemCellReuseIdentifier = "AddItem"
private let defaultChecklistName = "No Name"

class ChecklistViewController: UITableViewController {
  var checklist: Checklist! // Expected to be set on seque or right after init(). Behavior undefined if this is set/reset after viewDidLoad().

  @IBOutlet weak var checklistInfoHeaderView: UIView!
  @IBOutlet weak var checklistNameTextField: UITextField!
  @IBOutlet weak var checklistNotesTextView: GrowingTextView!

  /*
   Architectural Discussion:
   One option was to have each Cell hold a view controller and reset each cell+VC on cell reuse.
   Issue with that is preserving view state (such as expanded/collapsed, editing mode, etc.). If
   user scrolls it off screen, I'd have to capture it somehow and no easy way without maintaining
   an array.

   Another option was to have an array view controllers. This is cleaner but since users can
   arbitrarily reorder and remove Items, I would have to remember to update the VC array everytime
   I update the Checklist.items. Not that hard, but still.

   To account for above issues, easier to use a dictionary. This way, mapping will always sync up.
   */
  var itemViewControllersDict: [ String: ItemCellViewController ] = [:] // String = Item.id (i.e. the UUID)

  var isNewChecklist: Bool = false

  // For drag/reorder of cells.
  private var snapshotView: UIView = UIView()
  private var sourceIndexPath: IndexPath = IndexPath(row: 0, section: 0)

  override func viewDidLoad() {
    super.viewDidLoad()

    tableView.dragInteractionEnabled = true
    tableView.dragDelegate = self
    tableView.dropDelegate = self

    tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: itemCellReuseIdentifier)
    tableView.register(AddItemTableViewCell.self, forCellReuseIdentifier: AddItemCellReuseIdentifier)

    // Admittedly a bit hacky, as this is already in the view hierarchy in IB, but want to properly set it while not creating a separate xib file and custom UIView.
    tableView.tableHeaderView = checklistInfoHeaderView
    //  Despite Apple docs saying the width is set, it is not, and StackOverflow seems to only show manual methods like this.
    checklistInfoHeaderView.widthAnchor.constraint(equalTo: tableView.widthAnchor, multiplier: 1.0).isActive = true

    checklistNameTextField.delegate = self
    checklistNotesTextView.delegate = self

    checklistNameTextField.text = checklist.name
    checklistNotesTextView.text = checklist.notes

    if isNewChecklist {
      navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
    } else {
      navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Reset", style: .plain, target: self, action: #selector(resetButtonTapped))
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if isNewChecklist {
      isNewChecklist = false // safeguard against future times viewDidAppear might get called.
      checklistNameTextField.becomeFirstResponder()
    }
  }

  @objc func doneButtonTapped() {
    dismiss(animated: true, completion: nil)
  }

  @objc func resetButtonTapped() {
    DBManager.write {
      checklist.items.forEach { item in
        item.status = .unchecked
      }
    }
    tableView.reloadData()
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return checklist.items.count + 1
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == itemsSection {
      if indexPath.row >= 0 && indexPath.row < checklist.items.count {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: itemCellReuseIdentifier, for: indexPath) as? ItemTableViewCell else { assertionFailure(); return UITableViewCell() }

        let item = checklist.items[indexPath.row]
        let itemCellViewController = itemViewControllersDict[item.id] ?? ItemCellViewController(item: item, delegate: self)
        itemViewControllersDict[item.id] = itemCellViewController
        cell.setViewController(with: itemCellViewController)
        return cell
      } else if indexPath.row == checklist.items.count {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: AddItemCellReuseIdentifier, for: indexPath) as? AddItemTableViewCell else { assertionFailure(); return UITableViewCell() }
        cell.delegate = self
        return cell
      }
    }
    assertionFailure()
    return UITableViewCell()
  }

  override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
    return false
  }

  override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    if let childViewController = (cell as? ItemTableViewCell)?.itemCellViewController {
      addChild(childViewController)
      childViewController.didMove(toParent: self)
    }
  }

  override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    if let childViewController = (cell as? ItemTableViewCell)?.itemCellViewController {
      childViewController.willMove(toParent: nil)
      childViewController.removeFromParent()
    }
  }

  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    guard indexPath.section == itemsSection else { assertionFailure(); return }
    if editingStyle == .delete {
      checklist.remove(at: indexPath.row)
      tableView.deleteRows(at: [indexPath], with: .fade)
    } else if editingStyle == .insert {
      assertionFailure()
    }
  }

  override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
    guard indexPath.section == itemsSection else { assertionFailure(); return .none }
    return indexPath.row < checklist.items.count ? .delete : .none // Accounts for Add button.
  }

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    guard indexPath.section == itemsSection else { assertionFailure(); return false }
    return indexPath.row < checklist.items.count // Don't move the Add button.
  }

  override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    checklist.moveItem(from: sourceIndexPath.row, to: destinationIndexPath.row)
  }
}

extension ChecklistViewController: ItemCellViewControllerDelegate {
  func cellHeightRequiresRefresh() {
    tableView.beginUpdates()
    tableView.endUpdates()
  }
}

extension ChecklistViewController: UITextFieldDelegate {
  func textFieldDidEndEditing(_ textField: UITextField) {
    DBManager.write {
      checklist.name = checklistNameTextField.hasText ? checklistNameTextField.text ?? defaultChecklistName : defaultChecklistName // Accounts for both nil and empty string.
    }
  }
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return false
  }
}

extension ChecklistViewController: UITextViewDelegate {
  func textViewDidEndEditing(_ textView: UITextView) {
    DBManager.write {
      checklist.notes = checklistNotesTextView.text
    }
  }
}

extension ChecklistViewController: GrowingTextViewDelegate {
  func textViewDidChangeHeight(_ textView: GrowingTextView, height: CGFloat) {
    UIView.animate(withDuration: 0.2) {
      self.tableView.setNeedsLayout()
      self.tableView.layoutIfNeeded()
      self.tableView.tableHeaderView = self.checklistInfoHeaderView // According to StackOverflow, this seems to be the accepted-yet-janky way of pushing the cells down as the header expands.
    }
  }
}

extension ChecklistViewController: AddItemTableViewCellDelegate {
  func addItemTableViewCellTapped() {
    let item = Item(name: "", notes: nil)
    DBManager.write {
      checklist.items.append(item)
    }
    tableView.performBatchUpdates({
      tableView.insertRows(at: [IndexPath(row: checklist.items.count - 1, section: itemsSection)], with: .top)
    }, completion: { success in
      if success {
        self.itemViewControllersDict[item.id]?.startEditing()
      }
    })
  }
}

// MARK: - Drag/Drop Reorder

extension ChecklistViewController: UITableViewDragDelegate  {
  func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
    guard indexPath.section == itemsSection else { assertionFailure(); return [] }
    guard indexPath.row < checklist.items.count else { return [] } // Don't drag the Add button.
    return checklist.items[indexPath.row].dragItems()
  }
}

extension ChecklistViewController: UITableViewDropDelegate {
  func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
    return session.canLoadObjects(ofClass: NSString.self)
  }

  func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
    if tableView.hasActiveDrag {
      if session.items.count > 1 || destinationIndexPath?.row ?? -1 >= checklist.items.count { // Don't move past Add button.
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
