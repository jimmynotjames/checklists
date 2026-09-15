//
//  AddItemButtonTableFooterView.swift
//  checklists
//
//  Created by Jimmy Ho on 7/25/19.
//

import UIKit

protocol AddItemButtonTableFooterViewDelegate: AnyObject {
  func addItemTableViewCellTapped()
}

class AddItemButtonTableFooterView: UIView {
  weak var delegate: AddItemButtonTableFooterViewDelegate?

  /// This feels slightly hacky. Adding this so in landscape mode, I can still use VFL and adhere to layout margins while using custom inset.
  let contentView = UIView()

  let addButton: CLButton = {
    let button = CLButton(frame: .zero)
    button.configuration?.title = "Add"
    return button
  }()

  let metrics = ["spacing": 8.0,
                 "buttonHeight": 44.0]

  override init(frame: CGRect) {
    super.init(frame: frame)

    addSubview(contentView)
    contentView.addSubview(addButton)
    addButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

    let views: [String: UIView] = [
      "contentView": contentView,
      "addButton": addButton,
    ]

    views.forEach { $0.value.translatesAutoresizingMaskIntoConstraints = false }

    NSLayoutConstraint.activate(
      [NSLayoutConstraint.constraints(withVisualFormat: "V:|[contentView]|", metrics: metrics, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|-[contentView]-|", metrics: metrics, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "V:|-spacing-[addButton(==buttonHeight)]-spacing-|", metrics: metrics, views: views),
       NSLayoutConstraint.constraints(withVisualFormat: "H:|-spacing-[addButton]-spacing-|", metrics: metrics, views: views)].flatMap(\.self)
    )
    adjustFrameHeight()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError()
  }

  /// `UITableView.tableFooterView` needs its frame height set manually for correct layout.
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
