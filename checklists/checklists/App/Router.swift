//
//  Router.swift
//  checklists
//

import Foundation

/// Centralised navigation state for the SwiftUI shell, owned by the app's root view as `@State`
/// and injected into the environment so any descendant screen can push a destination or present a
/// sheet without a direct reference to the host. `isMainMenuVisible` drives a slide-in overlay
/// menu rather than a sheet, since it overlays the current screen instead of navigating away.
@Observable
@MainActor
final class Router {
  var path: [AppRoute] = []
  var sheet: SheetRoute?
  var isMainMenuVisible = false
}
