//
//  ChecklistTableViewCell.swift
//  checklists
//
//  Created by Jimmy Ho on 11/19/20.
//

import UIKit

class ChecklistTableViewCell: UITableViewCell {
  private var checklistContentView: ChecklistCellContentView = .init(frame: .zero)

  var checklist: Checklist? {
    get {
      checklistContentView.checklist
    }
    set {
      checklistContentView.checklist = newValue
    }
  }

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    commonSetup()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonSetup()
  }

  private func commonSetup() {
    backgroundColor = .clear
    installConstraints()
  }

  private func installConstraints() {
    contentView.addSubview(checklistContentView)
    checklistContentView.translatesAutoresizingMaskIntoConstraints = false

    [contentView.topAnchor.constraint(equalTo: checklistContentView.topAnchor),
     contentView.bottomAnchor.constraint(equalTo: checklistContentView.bottomAnchor),
     contentView.leftAnchor.constraint(equalTo: checklistContentView.leftAnchor),
     contentView.rightAnchor.constraint(equalTo: checklistContentView.rightAnchor)].forEach { $0.isActive = true }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    checklist = nil
  }
}
