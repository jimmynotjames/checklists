//
//  ActivityPresenter.swift
//  checklists
//

import SwiftUI
import UIKit

/// Presents the system share sheet from SwiftUI and reports whether the share went through.
///
/// `ShareLink` cannot be used: it never says whether the person shared or cancelled, and the export
/// sheet closes on one and stays open on the other. This puts an invisible controller into the
/// sheet's hierarchy to present from.
struct ActivityPresenter: UIViewControllerRepresentable {
  let proxy: ActivityPresenterProxy

  func makeUIViewController(context _: Context) -> UIViewController {
    let host = UIViewController()
    host.view.backgroundColor = .clear
    host.view.isUserInteractionEnabled = false
    proxy.host = host
    return host
  }

  func updateUIViewController(_: UIViewController, context _: Context) {}
}

@MainActor
final class ActivityPresenterProxy {
  weak var host: UIViewController?

  /// Shares `url`, calling `completion` once, when the share sheet is done, with whether the share
  /// completed.
  ///
  /// The URL rather than the data, so AirDrop, Mail and Files show the file's readable name.
  /// Returns `false`, without calling `completion`, if there is nowhere to present from.
  @discardableResult
  func present(url: URL, completion: @escaping @MainActor (Bool) -> Void) -> Bool {
    guard let host, host.viewIfLoaded?.window != nil else { return false }
    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    // iPhone only, but an iPad running the app in compatibility mode still asks for an anchor.
    activity.popoverPresentationController?.sourceView = host.view
    activity.popoverPresentationController?.sourceRect = host.view.bounds
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
      guard !completed, activityType != nil, let activity, Self.isStillPresented(activity) else {
        finish(completed)
        return
      }
      // Checked again once any dismissal has had time to start: some destinations close the
      // share sheet along with their own screen.
      Task { @MainActor [weak activity] in
        try? await Task.sleep(for: .milliseconds(600))
        if let activity, Self.isStillPresented(activity) {
          return
        }
        finish(false)
      }
    }
    var presenter = host
    while let presented = presenter.presentedViewController {
      presenter = presented
    }
    presenter.present(activity, animated: true)
    return true
  }

  private static func isStillPresented(_ activity: UIViewController) -> Bool {
    activity.presentingViewController != nil && !activity.isBeingDismissed
  }
}
