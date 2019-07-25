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
  var itemViewControllersDict: [ Item: ItemCellViewController ] = [:]

  // For drag/reorder of cells.
  var snapshotView: UIView = UIView()
  var sourceIndexPath: IndexPath = IndexPath(row: 0, section: 0)

  override func viewDidLoad() {
    super.viewDidLoad()

    // Admittedly a bit hacky, as this is already in the view hierarchy in IB, but want to properly set it while not creating a separate xib file and custom UIView.
    tableView.tableHeaderView = checklistInfoHeaderView

    checklistNameTextField.delegate = self
    checklistNotesTextView.delegate = self

    checklistNameTextField.text = checklist.name
    checklistNotesTextView.text = checklist.notes

    tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: itemCellReuseIdentifier)

    let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressGestureRecognizer(sender:)))
    longPressGestureRecognizer.minimumPressDuration = 0.25
    tableView.addGestureRecognizer(longPressGestureRecognizer)
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return checklist.items.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == itemsSection {
      guard let cell = tableView.dequeueReusableCell(withIdentifier: itemCellReuseIdentifier, for: indexPath) as? ItemTableViewCell else { assertionFailure(); return UITableViewCell() }
      guard indexPath.row >= 0 && indexPath.row < checklist.items.count else { assertionFailure(); return UITableViewCell() }

      let item = checklist.items[indexPath.row]
      let itemCellViewController = itemViewControllersDict[item] ?? ItemCellViewController(item: item, delegate: self)
      itemViewControllersDict[item] = itemCellViewController
      cell.setViewController(with: itemCellViewController)
      return cell
    } else {
      assertionFailure()
      return UITableViewCell()
    }
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
    guard indexPath.section == 0 else { assertionFailure(); return }
    if editingStyle == .delete {
      checklist.remove(at: indexPath.row)
      tableView.deleteRows(at: [indexPath], with: .fade)
    } else if editingStyle == .insert {
      assertionFailure()
    }
  }

  // TODO: This may not be necessary if I don't do a second section.
  override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
    guard indexPath.section == 0 else { assertionFailure(); return .none }
    return .delete
  }

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    guard indexPath.section == 0 else { assertionFailure(); return false } // TODO: May not be necessary if I don't do second section.
    return true
  }

  override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    checklist.moveItem(from: sourceIndexPath.row, to: destinationIndexPath.row)
  }
}

// MARK: - For Drag-drop reordering of cells.

extension ChecklistViewController {
  @objc func longPressGestureRecognizer(sender: Any) {
    guard let longPress = sender as? UILongPressGestureRecognizer else { assertionFailure(); return }
    let location = longPress.location(in: tableView)
    guard let indexPath = tableView.indexPathForRow(at: location) else { return }

    switch longPress.state {
    case .began: startDragging(at: indexPath, location: location)
    case .changed: dragging(at: indexPath, location: location)
    default: endDragging(at: indexPath, location: location)
    }
  }

  private func startDragging(at indexPath: IndexPath, location: CGPoint) {
    sourceIndexPath = indexPath
    guard let cell = tableView.cellForRow(at: indexPath) else { assertionFailure(); return }
    snapshotView = snapshotFrom(view: cell)
    var center = cell.center
    snapshotView.center = center
    snapshotView.alpha = 0.0
    tableView.addSubview(snapshotView)
    UIView.animate(withDuration: 0.15) {
      // Offset for gesture location.
      center.y = location.y
      self.snapshotView.center = cell.center
      self.snapshotView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
      self.snapshotView.alpha = 0.98
      cell.alpha = 0.0
      cell.isHidden = true
    }
  }

  private func dragging(at indexPath: IndexPath, location: CGPoint) {
    var center = snapshotView.center
    center.y = location.y
    snapshotView.center = center
    guard indexPath != sourceIndexPath else { return }
    checklist.swapItemsAt(sourceIndexPath.row, indexPath.row)
    tableView.moveRow(at: sourceIndexPath, to: indexPath)
    sourceIndexPath = indexPath
  }

  private func endDragging(at: IndexPath, location: CGPoint) {
    guard let cell = tableView.cellForRow(at: sourceIndexPath) else { assertionFailure(); return }
    cell.alpha = 0.0
    UIView.animate(withDuration: 0.1, animations: {
      self.snapshotView.center =  cell.center
      self.snapshotView.transform = CGAffineTransform.identity
      self.snapshotView.alpha = 0.0
      cell.alpha = 1.0
    }, completion: { finished in
      cell.isHidden = false
      self.snapshotView.removeFromSuperview()
    })
  }

  private func snapshotFrom(view: UIView) -> UIView {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0.0)
    guard let graphicsContext = UIGraphicsGetCurrentContext() else { UIGraphicsEndImageContext(); assertionFailure(); return UIView() }
    view.layer.render(in: graphicsContext)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    let snapshotView = UIImageView(image: image)
    snapshotView.layer.masksToBounds = false
    snapshotView.layer.cornerRadius = 0.0
    snapshotView.layer.shadowOffset = CGSize(width: -5.0, height: 0.0)
    snapshotView.layer.shadowRadius = 5.0
    snapshotView.layer.shadowOpacity = 0.4

    return snapshotView
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
      checklist.name = checklistNameTextField.text ?? "No Name"
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
