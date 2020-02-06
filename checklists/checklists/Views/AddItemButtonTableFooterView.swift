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

  // This feels slightly hacky. Adding this so in landscape mode, I can still use VFL and adhere to layout margins while using custom inset.
  let contentView = UIView()

  let addButton: CLButton = {
    let button = CLButton(frame: .zero)
    button.setTitle("Add", for: .normal)
    return button
  }()

  let metrics = [ "spacing": 8.0,
                  "buttonHeight": 44.0 ]

  override init(frame: CGRect) {
    super.init(frame: frame)

    addSubview(contentView)
    contentView.addSubview(addButton)
    addButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

    let views: [ String: UIView ]  = [
      "contentView": contentView,
      "addButton": addButton
    ]

    views.forEach({ $0.value.translatesAutoresizingMaskIntoConstraints = false })

    NSLayoutConstraint.activate(
      [NSLayoutConstraint.constraints(withVisualFormat: "V:|[contentView]|", metrics: metrics, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|-[contentView]-|", metrics: metrics, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "V:|-spacing-[addButton(==buttonHeight)]-spacing-|", metrics: metrics, views: views),
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
