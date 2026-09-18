//
//  UITableView+HeaderSizing.swift
//  checklists
//

import UIKit

extension UITableView {
  /// Sizes `tableHeaderView` against this table's real width.
  ///
  /// A `tableHeaderView` is positioned by frame and its height is read once, at assignment — there
  /// is no self-sizing equivalent of `estimatedRowHeight` for it. A view controller's `viewDidLoad`
  /// runs while its table is still zero-wide, so a header measured there comes out too short and
  /// draws over the first rows.
  ///
  /// Call from `viewDidLayoutSubviews`, and again whenever the header's content changes. The header
  /// must be frame-driven (`translatesAutoresizingMaskIntoConstraints = true`); its subviews stay on
  /// Auto Layout.
  func resizeTableHeaderToFit() {
    guard let header = tableHeaderView, bounds.width > 0.0 else { return }
    let height = header.systemLayoutSizeFitting(
      CGSize(width: bounds.width, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    ).height
    // Reassigning is what makes the table re-read the height, and it triggers another layout pass,
    // so only do it on a real change or this recurses. The width term covers rotation.
    guard abs(height - header.frame.height) > 0.5 || abs(bounds.width - header.frame.width) > 0.5 else { return }
    header.frame = CGRect(x: 0.0, y: 0.0, width: bounds.width, height: height)
    tableHeaderView = header
  }
}
