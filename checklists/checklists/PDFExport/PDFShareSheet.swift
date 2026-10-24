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
  static func present(url: URL, from presenter: UIViewController, sourceItem: UIBarButtonItem?, completion: @escaping @MainActor (Bool) -> Void) {
    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    // iPhone only, but an iPad running the app in compatibility mode still asks for an anchor.
    if let sourceItem {
      activity.popoverPresentationController?.sourceItem = sourceItem
    } else {
      activity.popoverPresentationController?.sourceView = presenter.view
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
      // Checked again once any dismissal has had time to start: some destinations close the
      // share sheet along with their own screen.
      Task { @MainActor [weak activity] in
        try? await Task.sleep(for: .milliseconds(600))
        if let activity, isStillPresented(activity) {
          return
        }
        finish(false)
      }
    }
    presenter.present(activity, animated: true)
  }

  private static func isStillPresented(_ activity: UIViewController) -> Bool {
    activity.presentingViewController != nil && !activity.isBeingDismissed
  }
}
