//
//  PDFShareSheet.swift
//  checklists
//

import UIKit

/// Presents the system share sheet for an exported PDF and reports, once, whether the share went
/// through.
enum PDFShareSheet {
  /// The URL rather than the data, so AirDrop, Mail and Files show the file's readable name.
  /// `completion` runs when the share sheet is done, not when one destination inside it closes.
  static func present(url: URL, from presenter: UIViewController, completion: @escaping @MainActor (Bool) -> Void) {
    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    // iPhone only, but an iPad running the app in compatibility mode still asks for an anchor. The
    // top trailing corner of what is on screen, under ⋯, which as a SwiftUI toolbar item has no
    // UIKit handle to anchor on.
    if let popover = activity.popoverPresentationController, let view = presenter.view {
      let bounds = view.bounds
      let isRightToLeft = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
      popover.sourceView = view
      popover.sourceRect = CGRect(x: isRightToLeft ? bounds.minX : bounds.maxX, y: bounds.minY, width: 0, height: 0)
      popover.permittedArrowDirections = .up
    }
    var isFinished = false
    let finish = { (completed: Bool) in
      guard !isFinished else { return }
      isFinished = true
      completion(completed)
    }
    activity.completionWithItemsHandler = { [weak activity] activityType, completed, _, _ in
      // Backing out of a destination's own screen, such as a Mail draft, reports a cancel while
      // the share sheet stays up for another pick, and the file must still be there for it. Only a
      // share sheet that is actually closing ends the share.
      guard !completed, activityType != nil, let activity, isStillPresented(activity) else {
        finish(completed)
        return
      }
      // Watched until it is gone: some destinations close the share sheet along with their own
      // screen, which reports nothing further. A share sheet that stays up reports again when it
      // closes, and that ends the watch.
      Task { @MainActor [weak activity] in
        while !isFinished {
          try? await Task.sleep(for: .milliseconds(500))
          guard let activity, isStillPresented(activity) else {
            finish(false)
            return
          }
        }
      }
    }
    presenter.present(activity, animated: true)
  }

  private static func isStillPresented(_ activity: UIViewController) -> Bool {
    activity.presentingViewController != nil && !activity.isBeingDismissed
  }
}
