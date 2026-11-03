//
//  ChecklistViewController+BarHost.swift
//  checklists
//

import UIKit

/// Shows this screen's bar items in the SwiftUI navigation bar around it, not in its own.
///
/// iPhone Duo's vertical bar only takes the items of a window's outermost navigation bar: the
/// embedded `ChecklistNavigationController` reports `verticalBarEdge` as unspecified, so items left
/// in its bar stay in a horizontal bar above the checklist. Lending them to the SwiftUI host's
/// navigation item lets the system move them into the column, as it does on every other screen.
///
/// The controller's own `navigationItem` stays the one the rest of the screen and its tests read
/// and write; `mirrorBarToHost` copies it across. SwiftUI owns the host's navigation item and
/// documents nothing about leaving items it didn't put there, so the copy is re-asserted on every
/// layout pass and every SwiftUI update, not only when this screen changes its bar. Issue #353
/// tracks replacing this with a SwiftUI toolbar.
extension ChecklistViewController {
  /// The navigation item of the SwiftUI view this screen is pushed or presented in, when that view
  /// sits in a navigation stack whose bar is the one on screen. `nil` in a bare host, such as a
  /// unit test's window, where the controller's own bar is the only one.
  private var barHostItem: UINavigationItem? {
    guard let host = navigationController?.parent, host.navigationController != nil else { return nil }
    return host.navigationItem
  }

  /// Copies the bar to the host, touching only what differs, so it is cheap enough for every
  /// layout pass and leaves an unchanged bar alone mid-animation.
  func mirrorBarToHost(animated: Bool = false) {
    guard let host = barHostItem, let hostController = navigationController?.parent else { return }
    // The bar's scroll-edge treatment follows the table, two containers down from the host.
    if let table = viewIfLoaded as? UIScrollView, hostController.contentScrollView(for: .top) !== table {
      hostController.setContentScrollView(table, for: .top)
    }
    if navigationController?.isNavigationBarHidden == false {
      navigationController?.setNavigationBarHidden(true, animated: false)
    }
    let own = navigationItem
    // The host's own back button stands in for one here: the system puts it first in the vertical
    // bar, above the pinned Done, which a hand-built leading item would not get.
    if host.hidesBackButton != own.hidesBackButton {
      host.setHidesBackButton(own.hidesBackButton, animated: animated)
    }
    let ownRight = own.rightBarButtonItems ?? []
    if !(host.rightBarButtonItems ?? []).elementsEqual(ownRight, by: ===) {
      host.setRightBarButtonItems(ownRight, animated: animated)
    }
    if host.pinnedTrailingGroup?.barButtonItems.first !== own.pinnedTrailingGroup?.barButtonItems.first {
      host.pinnedTrailingGroup = own.pinnedTrailingGroup
    }
    if host.title != own.title {
      host.title = own.title
    }
  }
}
