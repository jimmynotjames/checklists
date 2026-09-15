//
//  CLTextField.swift
//  checklists
//
//  Created by Jimmy Ho on 8/24/19.
//

import UIKit

/// Unlike `UITextView` (see `CLTextView`), `UITextField` requires the drop delegate to be set explicitly.
class CLTextField: UITextField {
  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  func commonInit() {
    textDropDelegate = self
  }
}

/// Need this because the reordering of rows using Drag/Drop is causing it to accidentally drop into Checklist's Name field.
extension CLTextField: UITextDropDelegate {
  /// See CLTextView's TECH DEBT note.
  func textDroppableView(_: UIView & UITextDroppable, proposalForDrop _: UITextDropRequest) -> UITextDropProposal {
    UITextDropProposal(operation: .forbidden)
  }
}
