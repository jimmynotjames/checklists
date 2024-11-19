//
//  ChecklistCellContentView.swift
//  checklists
//
//  Created by Jimmy Ho on 12/4/20.
//  Copyright © 2020 Jimmy Ho. All rights reserved.
//

import UIKit

class ChecklistCellContentView: UIView {
  var checklist: Checklist? {
    didSet {
      nameLabel.text = checklist?.name
      notesLabel.text = checklist?.notes
      statusIcon.percentageComplete = checklist?.percentageComplete ?? 0.0
    }
  }

  private let statusIcon = LegacyCircularPercentStatusIcon(iconType: .tableViewCell)

  private let nameLabel: UILabel = {
    let label = UILabel()
    label.textColor = .black
    label.font = .systemFont(ofSize: 18.0, weight: .semibold)
    label.backgroundColor = .clear
    label.isUserInteractionEnabled = false
    label.numberOfLines = 1
    return label
  }()

  private let notesLabel: UILabel = {
    let label = UILabel()
    label.textColor = .black
    label.font = .systemFont(ofSize: 15.0)
    label.backgroundColor = .clear
    label.isUserInteractionEnabled = false
    label.numberOfLines = 3
    label.accessibilityIdentifier = "checklistNotesLabel"
    return label
  }()

  convenience init() {
    self.init(frame: .zero)
  }

  override init(frame: CGRect) {
    super.init(frame: frame)

    addSubview(statusIcon)
    addSubview(nameLabel)
    addSubview(notesLabel)

    installConstraints()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("This init() not supported.")
  }


  private func installConstraints() {
    let views = [ "itemContentView": self, // No actual effect, except to suppress intermediate unsatisfiable constraint warnings.
                  "statusIcon": statusIcon,
                  "nameLabel": nameLabel,
                  "notesLabel": notesLabel ]
    views.forEach({ $0.value.translatesAutoresizingMaskIntoConstraints = false })

    let metrics = [ "margin": 16.0 ]

    NSLayoutConstraint.activate(
      [NSLayoutConstraint.constraints(withVisualFormat: "H:|-(margin)-[statusIcon]-7-[nameLabel]-(margin)-|", options: [], metrics: metrics, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|-(margin)-[notesLabel]-(margin)-|", options: [], metrics: metrics, views: views),
       [statusIcon.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor)],
       NSLayoutConstraint.constraints(withVisualFormat: "V:|-[nameLabel]-[notesLabel]-|", options: [], metrics: metrics, views: views),
        ].flatMap({ $0 }))
  }
}
