//
//  Router.swift
//  checklists
//

import Foundation

/// Centralised navigation state for the SwiftUI shell.
///
/// Owned by the app's root view as `@State` and injected into the environment so any
/// descendant screen can push a new destination or present a sheet without needing a
/// direct reference to the host.
///
/// Modeled on `simple-recurring-budgets`'s `Router`, with one deviation: `isMainMenuVisible`
/// drives a slide-in overlay menu (this app's replacement for the UIKit hamburger menu), not a
/// sheet. That repo has no equivalent — every one of its destinations is either a push
/// (`path`) or a sheet (`sheet`). The main menu is neither: it overlays the current
/// screen without navigating away from it, so it gets its own flag rather than being
/// forced into `SheetRoute`.
///
/// Usage in a leaf screen:
/// ```swift
/// @Environment(Router.self) private var router
/// // …
/// router.sheet = .settings
/// router.path.append(.checklist(id: checklist.id))
/// ```
@Observable
@MainActor
final class Router {
  var path: [AppRoute] = []
  var sheet: SheetRoute?
  var isMainMenuVisible = false
}
