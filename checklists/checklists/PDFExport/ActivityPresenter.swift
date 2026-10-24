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

  /// Shares `url`, calling `completion` once with whether the share completed.
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
    activity.completionWithItemsHandler = { _, completed, _, _ in
      completion(completed)
    }
    var presenter = host
    while let presented = presenter.presentedViewController {
      presenter = presented
    }
    presenter.present(activity, animated: true)
    return true
  }
}
