//
//  RealmSchema.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//

import Foundation
import RealmSwift
import UIKit
import UniformTypeIdentifiers

private extension String? {
  /// Whether a stored optional notes value differs from what a text view reported.
  ///
  /// Treats nil and "" as the same value. Notes start out nil while text views always report "",
  /// so a plain `!=` would read focusing-and-blurring an untouched field as a real edit and stamp
  /// `lastModified` for it. Encoded once here so no future comparison site can omit it.
  func differs(from other: String) -> Bool {
    (self ?? "") != other
  }
}

/**
 Current implementation is for this to be a singleton-style object,
 using the List to preserve arbitrary ordering of the Checklists.
 Perhaps in the future, some sort of tagging or folder structure
 could be implemented, which would result in more Group objects.
 */
class Group: Object {
  @objc dynamic var id = NSUUID().uuidString

  let checklists = List<Checklist>()

  override nonisolated init() {
    super.init()
  }

  func moveChecklist(from fromIndex: Int, to toIndex: Int) {
    guard fromIndex >= 0, fromIndex < checklists.count else { assertionFailure(); return }
    guard toIndex >= 0, toIndex < checklists.count else { assertionFailure(); return }
    guard fromIndex != toIndex else { return }

    DBManager.write {
      checklists.move(from: fromIndex, to: toIndex)
    }
  }
}

class Checklist: Object {
  @objc dynamic var id = NSUUID().uuidString
  @objc dynamic var name: String = ""
  @objc dynamic var notes: String?
  @objc dynamic var sortNumber: Double = 0.0
  @objc dynamic var lastModified: Date = .init()

  let items = List<Item>()

  var percentageComplete: CGFloat {
    guard !items.isEmpty else { return 0.0 }
    return CGFloat(items.count(where: { $0.status == .checked })) / CGFloat(items.count)
  }

  override nonisolated init() {
    super.init()
  }

  convenience init(name: String, notes: String? = nil, sortNumber: Double? = nil, items: [Item]) {
    self.init()
    self.name = name
    self.notes = notes
    if let sortNumber {
      self.sortNumber = sortNumber
    }
    self.items.append(objectsIn: items)
  }

  /// Renames the checklist, stamping `lastModified` only if the name actually changes. The caller
  /// resolves what an empty field means — this takes the resolved name.
  func setName(_ newName: String) {
    guard name != newName else { return }
    DBManager.write(touching: self) {
      name = newName
    }
  }

  /// Updates the notes, stamping `lastModified` only if they actually change.
  func setNotes(_ newNotes: String) {
    guard notes.differs(from: newNotes) else { return }
    DBManager.write(touching: self) {
      notes = newNotes
    }
  }

  /// Gives an empty checklist a blank row to type into. Never stamps: this is UI scaffolding the
  /// user never asked for, so merely opening an empty checklist must not modify it.
  func appendPlaceholderItemIfEmpty() {
    guard items.isEmpty else { return }
    DBManager.write {
      items.append(Item(name: "", notes: nil))
    }
  }

  /// Inserts a blank row for the user to type into. Never stamps: the row is empty and may be
  /// pruned again on exit. The modification is recorded once the user types into it.
  func insertPlaceholderItem(at index: Int) {
    guard index >= 0, index <= items.count else { assertionFailure(); return }
    DBManager.write {
      items.insert(Item(name: "", notes: nil), at: index)
    }
  }

  /// Drops 'dangling' empty rows from the end of the list, keeping one lone empty item. Never
  /// stamps: it removes nothing the user typed, and pairs with `appendPlaceholderItemIfEmpty`.
  func pruneTrailingEmptyItems() {
    DBManager.write {
      var i = items.count - 1
      while i > 0 {
        let item = items[i]
        if item.isEmpty {
          DBManager.realm.delete(item)
        } else {
          break
        }
        i -= 1
      }
    }
  }

  func remove(at index: Int) {
    guard index >= 0, index < items.count else { assertionFailure(); return }
    let item = items[index]
    // Dropping an empty placeholder row (e.g. backspacing on it) removes no user content,
    // so it must not count as modifying the checklist.
    DBManager.write(touching: item.isEmpty ? nil : self) {
      items.remove(at: index)
      DBManager.realm.delete(item)
    }
  }

  func swapItemsAt(_ index1: Int, _ index2: Int) {
    guard index1 >= 0, index1 < items.count else { assertionFailure(); return }
    guard index2 >= 0, index2 < items.count else { assertionFailure(); return }
    guard index1 != index2 else { return }

    DBManager.write(touching: self) {
      items.swapAt(index1, index2)
    }
  }

  func moveItem(from fromIndex: Int, to toIndex: Int) {
    guard fromIndex >= 0, fromIndex < items.count else { assertionFailure(); return }
    guard toIndex >= 0, toIndex < items.count else { assertionFailure(); return }
    guard fromIndex != toIndex else { return }

    DBManager.write(touching: self) {
      items.move(from: fromIndex, to: toIndex)
    }
  }

  func uncheckAllItems() {
    // Resetting a checklist that has nothing checked changes no stored value, so it isn't a
    // modification. Matters because "Reset all" sweeps every checklist, touched or not.
    let hasCheckedItems = items.contains { $0.status == .checked }
    DBManager.write(touching: hasCheckedItems ? self : nil) {
      for item in items {
        item.status = .unchecked
      }
    }
  }

  func dragItems() -> [UIDragItem] {
    let itemProvider = NSItemProvider()
    let id = id
    itemProvider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .ownProcess) { completion in
      let data = id.data(using: .utf8)
      completion(data, nil)
      return nil
    }
    return [UIDragItem(itemProvider: itemProvider)]
  }
}

class Item: Object {
  enum Status: Int {
    case unchecked
    case checked

    nonisolated static let defaultValue: Status = .unchecked
  }

  @objc dynamic var id = NSUUID().uuidString
  @objc dynamic var name: String = ""
  @objc dynamic var notes: String?
  @objc dynamic var statusRaw: Int = Status.defaultValue.rawValue

  /**
   Inverse relationship back to the owning Checklist, so an Item can stamp its own parent instead
   of relying on every call site to know one. This is what makes the `lastModified` invariant a
   property of the model rather than of call-site discipline.

   Costs no migration: `LinkingObjects` is a computed backlink, and Realm's schema diff compares
   only persisted properties. Note this is a *different* reason from `isEmpty` below, which never
   enters the schema at all.
   */
  let checklists = LinkingObjects(fromType: Checklist.self, property: "items")

  /// The Checklist that owns this item. Nil when the item is unmanaged or already detached — both
  /// cases where there is correctly nothing to stamp. The app never puts one Item in two
  /// Checklists, so the first link is the owner.
  private var parentChecklist: Checklist? {
    checklists.first
  }

  var status: Status {
    get {
      Status(rawValue: statusRaw) ?? Status.defaultValue
    }
    set {
      statusRaw = newValue.rawValue
    }
  }

  /// True when the item holds no user content — a placeholder row, not something worth
  /// timestamping the parent Checklist for. Deliberately not `@objc dynamic`: it is a computed
  /// Swift property and must stay out of the Realm schema so this needs no migration.
  var isEmpty: Bool {
    name.isEmpty && (notes?.isEmpty ?? true)
  }

  override nonisolated init() {
    super.init()
  }

  convenience init(name: String, notes: String? = nil) {
    self.init()
    self.name = name
    self.notes = notes
  }

  /// Renames the item, stamping the parent checklist only if the name actually changes.
  func setName(_ newName: String) {
    guard name != newName else { return }
    DBManager.write(touching: parentChecklist) {
      name = newName
    }
  }

  /// Updates the item's notes, stamping the parent checklist only if they actually change.
  func setNotes(_ newNotes: String) {
    guard notes.differs(from: newNotes) else { return }
    DBManager.write(touching: parentChecklist) {
      notes = newNotes
    }
  }

  /// Flips the checkbox. Opens its own write, so callers need not wrap it; a toggle always changes
  /// the stored status, so it always stamps the parent.
  func toggleStatus() {
    DBManager.write(touching: parentChecklist) {
      switch status {
      case .unchecked: status = .checked
      case .checked: status = .unchecked
      }
    }
  }

  func dragItems() -> [UIDragItem] {
    let itemProvider = NSItemProvider()
    let id = id
    itemProvider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .ownProcess) { completion in
      let data = id.data(using: .utf8)
      completion(data, nil)
      return nil
    }
    return [UIDragItem(itemProvider: itemProvider)]
  }
}
