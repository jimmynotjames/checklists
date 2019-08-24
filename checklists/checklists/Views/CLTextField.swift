//
//  CLTextField.swift
//  checklists
//
//  Created by Jimmy Ho on 8/24/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

/*
 Honestly, I don't know why I have to set the delegate explicitly here for UITextField but for UITextView (see CLTextView),
 I just had to implement the delegate method. The UITextField by default accepts drop events, so I'm confused why it wasn't already set.
 But not worth time to investigate at this point.
 */
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

// Need this because the reordering of rows using Drag/Drop is causing it to accidentally drop into Checklist's Name field.
extension CLTextField: UITextDropDelegate {
  // TODO: This may have long-term consequences in iPad and Mac App, if we move there. Maybe people will want to drop text in there??
  func textDroppableView(_ textDroppableView: UIView & UITextDroppable, proposalForDrop drop: UITextDropRequest) -> UITextDropProposal {
    return UITextDropProposal(operation: .forbidden)
  }
}
