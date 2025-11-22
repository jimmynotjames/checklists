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

/**
 In SwiftUI, it appears that dragging a Checklist to end of list goes to `count`.
 However, Realm calculates the indices as if the origin index was removed, so
 adding at the end is actually count-1. Realm will throw an exception if destination is `count`.
 More generally, if the item is moving further down the list, Realm's destination index
 will be -1 from SwiftUI's destination index because of this effect.
 */
func realmDestinationIndex(sourceIndex: Int, swiftUIDestinationIndex destIndex: Int) -> Int {
  return sourceIndex < destIndex ? destIndex - 1 : destIndex
}
