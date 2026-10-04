//
//  ReadableColumn.swift
//  checklists
//

import UIKit

/// The widest a screen's content column grows before it stops following the window and centers
/// instead. iPhone-only apps still get arbitrarily wide windows — the unfolded iPhone Duo, a resized
/// iPad window, iPhone Mirroring — and rows stretched across all of that read badly. Every iPhone
/// in portrait is narrower than this, so there the column is simply the full width.
let readableColumnMaxWidth: CGFloat = 672

/// The horizontal margin that centers a `readableColumnMaxWidth` column in `width`; zero when
/// `width` is narrower. For SwiftUI, which has no layout guide to pin to.
func readableColumnMargin(for width: CGFloat) -> CGFloat {
  max(0, (width - readableColumnMaxWidth) / 2)
}

extension UIView {
  /// Adds and returns a full-height guide spanning this view's safe area, capped at
  /// `readableColumnMaxWidth` and centered. Pin content to it instead of the view's own edges.
  ///
  /// The safe area rather than the bounds keeps landscape content clear of the sensor housing.
  func addReadableColumnGuide() -> UILayoutGuide {
    let guide = UILayoutGuide()
    addLayoutGuide(guide)
    let safeArea = safeAreaLayoutGuide
    let fillsSafeArea = guide.widthAnchor.constraint(equalTo: safeArea.widthAnchor)
    // Below the cap, so the cap wins on a wide window.
    fillsSafeArea.priority = .defaultHigh
    NSLayoutConstraint.activate([
      guide.topAnchor.constraint(equalTo: topAnchor),
      guide.bottomAnchor.constraint(equalTo: bottomAnchor),
      guide.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
      guide.widthAnchor.constraint(lessThanOrEqualToConstant: readableColumnMaxWidth),
      guide.widthAnchor.constraint(lessThanOrEqualTo: safeArea.widthAnchor),
      fillsSafeArea,
    ])
    return guide
  }
}
