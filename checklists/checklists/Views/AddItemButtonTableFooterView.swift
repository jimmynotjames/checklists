//
//  AddItemFooterView.swift
//  checklists
//
//  Created by Jimmy Ho on 7/25/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

protocol AddItemButtonTableFooterViewDelegate: class {
  func addItemTableViewCellTapped()
}

class AddItemButtonTableFooterView: UIView {
  weak var delegate: AddItemButtonTableFooterViewDelegate?

  let addButton: CLButton = {
    let button = CLButton(frame: .zero)
    button.setTitle("Add", for: .normal)
    return button
  }()

  let metrics = [ "spacing": 16.0,
                  "buttonHeight": 44.0 ]

  override init(frame: CGRect) {
    super.init(frame: frame)

    addSubview(addButton)
    addButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

    let views: [ String: UIView ]  = [
      "addButton": addButton
    ]

    addButton.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate(
      [NSLayoutConstraint.constraints(withVisualFormat: "V:|-spacing-[addButton(==buttonHeight)]-spacing-|", metrics: metrics, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|-spacing-[addButton]-spacing-|", metrics: metrics, views: views),
        ].flatMap({ $0 }))

    adjustFrameHeight()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }

  /*
   UITableView's way of handling tableFooterView is frustrating to say the least,
   and from StackOverflow and experimentations, looks like I need to set the frame
   height manually and somehow, this magically helps the table view lay out this view.
   */
  func adjustFrameHeight() {
    guard
      let spacing = metrics["spacing"],
      let buttonHeight = metrics["buttonHeight"]
      else { assertionFailure(); return }
    frame.size.height = CGFloat(spacing * 2.0 + buttonHeight)
  }

  @objc func buttonTapped() {
    delegate?.addItemTableViewCellTapped()
  }

}
