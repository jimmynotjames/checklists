//
//  DonateViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 8/11/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

class DonateViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
  }

  @objc func doneButtonTapped() {
    dismiss(animated: true, completion: nil)
  }
}
