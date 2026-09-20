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

 An insertion between two rows takes their midpoint; at the head it halves the leading key, and at
 the tail it adds `step`. So the ordinary case rewrites exactly one record instead of renumbering
 everything after it, which matters for sync: a renumber pushes the whole list into a merge. The
 cost is that repeated insertions at the same interior spot halve the available gap each time, so
 once a gap gets too small to split, the caller renormalizes the list back to 1, 2, 3… and retries.
 */
enum SortKeyReorder {
  /// The smallest gap still considered splittable.
  ///
  /// A policy floor, not a representability limit — `Double` has 52 bits of mantissa, so keys near
  /// 1.0 could be subdivided some fifty times before they stopped being distinct. This stops at
  /// **twenty**: the gap after *n* insertions at one spot is 2⁻ⁿ, and 2⁻²⁰ is the first below this.
  /// The conservatism is deliberate: it keeps a wide margin over the coarsest keys in play, which
  /// are the legacy import's.
  nonisolated static let epsilon: Double = 1e-6

  /// Spacing used by `renormalize` and by the first key in an empty list.
  nonisolated static let step: Double = 1.0

  /// The sort key for an element being placed at `index` among `neighborKeys`.
  ///
  /// - Parameters:
  ///   - index: the destination position, in the range `0...neighborKeys.count`. An empty
  ///     `neighborKeys` returns `step` whatever the index.
  ///   - neighborKeys: the sort keys of the other elements, ascending, **excluding** the element
  ///     being placed.
  /// - Returns: the new key, or `nil` when there is no room left, meaning the caller must
  ///   `renormalize` first and then ask again. Only the head and interior cases can run out:
  ///   appending is always `last + step`.
  nonisolated static func key(forInsertingAt index: Int, in neighborKeys: [Double]) -> Double? {
    guard let first = neighborKeys.first, let last = neighborKeys.last else { return step }

    if index <= 0 {
      // Halve the leading key rather than subtracting, so keys stay positive as the user adds to
      // the top of the list. The guard is on the key itself rather than on a gap, since the space
      // below the first row is bounded by zero: once it drops under `epsilon` there is no more
      // room and the caller renormalizes.
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
