//
//  Utilities.swift
//  checklists
//
//  Created by Jimmy Ho on 12/10/24.
//  Copyright © 2024 Jimmy Ho. All rights reserved.
//

extension String {
  /// Returns a new string with leading and trailing whitespace and newlines removed.
  func trimmed() -> String {
    self.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
