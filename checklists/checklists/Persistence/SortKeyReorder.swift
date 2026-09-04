//
//  SortKeyReorder.swift
//  checklists
//

import Foundation

/**
 Arithmetic for user-defined ordering, kept separate from SwiftData so it can be tested as pure
 functions.

 CloudKit relationships are unordered sets, so "the order the user dragged things into" has to be
 stored as data rather than inferred from an array. Each record carries a `Double` sort key and
 rows are displayed in ascending key order.

 Insertions take the midpoint between the two neighbours, so moving one row rewrites exactly one
 record instead of renumbering everything after it. That matters for sync: a renumber would push
 the whole list into a merge on every reorder. The cost is that repeated insertions at the same
 spot halve the available gap each time, so once a gap gets too small to split, the caller
 renormalizes the list back to 1, 2, 3… and retries.
 */
enum SortKeyReorder {
  /// Below this, halving the gap stops producing distinct `Double`s reliably. Reached only after
  /// roughly fifty consecutive insertions at the same position, so renormalization is rare.
  nonisolated static let epsilon: Double = 1e-6

  /// Spacing used by `renormalize` and by the first key in an empty list.
  nonisolated static let step: Double = 1.0

  /// The sort key for an element being placed at `index` among `neighborKeys`.
  ///
  /// - Parameters:
  ///   - index: the destination position, in the range `0...neighborKeys.count`.
  ///   - neighborKeys: the sort keys of the other elements, ascending, **excluding** the element
  ///     being placed.
  /// - Returns: the new key, or `nil` when the surrounding gap is smaller than `epsilon`, meaning
  ///   the caller must `renormalize` first and then ask again.
  nonisolated static func key(forInsertingAt index: Int, in neighborKeys: [Double]) -> Double? {
    guard let first = neighborKeys.first, let last = neighborKeys.last else { return step }

    if index <= 0 {
      // Halve the leading key rather than subtracting, so keys stay positive no matter how many
      // times the user adds to the top of the list.
      return first >= epsilon ? first / 2.0 : nil
    }
    if index >= neighborKeys.count {
      return last + step
    }

    let before = neighborKeys[index - 1]
    let after = neighborKeys[index]
    guard after - before >= epsilon else { return nil }
    return before + (after - before) / 2.0
  }

  /// Reassigns evenly spaced keys (1, 2, 3, …) to `elements` in their current order.
  ///
  /// Called only when `key(forInsertingAt:in:)` runs out of room. Rewrites every element, so it is
  /// the expensive path by design.
  nonisolated static func renormalize<Element>(_ elements: [Element], assign: (Element, Double) -> Void) {
    for (offset, element) in elements.enumerated() {
      assign(element, Double(offset + 1) * step)
    }
  }
}
