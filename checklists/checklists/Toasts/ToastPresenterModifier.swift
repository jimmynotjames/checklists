//
//  ToastPresenterModifier.swift
//  checklists
//

import SwiftUI

/// Where a toast layer sits, which decides when it is the one that draws.
enum ToastPlacement: Equatable {
  /// `ChecklistsView`, the navigation stack's root.
  case list
  /// A screen pushed onto the router's path.
  case pushed(AppRoute)
  /// The root view of whatever sheet the router presents.
  case sheet
}

/// Draws whatever toast is up, over one screen's content.
///
/// Applied inside each screen's `NavigationStack` rather than once over the whole window, so the
/// card is laid out in the screen's safe area. That area already excludes the bars wherever the
/// system puts them — `ChecklistsView`'s bottom toolbar, or the vertical bar on iPhone Duo — so the
/// card clears them without knowing their size. Exactly one layer draws at a time, the one on the
/// frontmost screen; announcing and timing belong to `ToastCoordinator` at the root.
private struct ToastOverlay: ViewModifier {
  /// How far the card sits above the safe area.
  private static let bottomInset: CGFloat = 16

  let placement: ToastPlacement

  @Environment(ToastPresenter.self) private var presenter
  @Environment(Router.self) private var router
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .bottom) {
        if let toast = presenter.current, drawsHere {
          ToastView(toast: toast) {
            presenter.dismiss()
          } onAction: {
            // Retired before the handler runs, not after: a handler that raises a toast of its
            // own — the shape a confirmed Undo takes — would otherwise have it cleared by this
            // very dismissal.
            presenter.dismiss()
            toast.action?.handler()
          }
          .padding(.horizontal, 16)
          // In line with the list's rows on a wide window rather than spanning it.
          .frame(maxWidth: readableColumnMaxWidth)
          // From the safe area, which includes the keyboard, so with the keyboard up the card
          // rides above it.
          .padding(.bottom, Self.bottomInset)
          .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
      }
      // Value-scoped on purpose. `withAnimation` inside the presenter would be transaction-scoped
      // and animate every other change in the same update turn.
      .animation(.easeInOut(duration: 0.25), value: presenter.current?.id)
  }

  /// A screen under a pushed one, or under a sheet, stays mounted, so every layer checks that its
  /// screen is the frontmost. The sheet's check is not redundant: a dismissing sheet's content stays
  /// mounted for its slide-out, so a toast raised just after `dismiss()` would otherwise be drawn
  /// by both the sheet and the screen beneath it.
  private var drawsHere: Bool {
    switch placement {
    case .sheet: router.sheet != nil
    case .list: router.sheet == nil && router.path.isEmpty
    case let .pushed(route): router.sheet == nil && router.path.last == route
    }
  }
}

/// Announces each toast and clears it on backgrounding, once for the whole app; `ToastOverlay`
/// does the drawing.
private struct ToastCoordinator: ViewModifier {
  @Environment(ToastPresenter.self) private var presenter
  @Environment(Router.self) private var router
  @Environment(\.scenePhase) private var scenePhase

  /// When the last sheet started closing, so an announcement raised as it goes can wait it out.
  @State private var sheetClosedAt: ContinuousClock.Instant?

  func body(content: Content) -> some View {
    content
      // Keyed on the toast, not its message: a repeat with the same words is still news — a
      // second copy into the same checklist, a second failed save — and under VoiceOver the first
      // never timed out, so keying on the words would leave the second unspoken. A replaced
      // toast's pending announcement is cancelled with it.
      .task(id: presenter.current?.id) { await announceCurrent() }
      // `dismiss()` clears `router.sheet` as the slide-out starts, in the same update that
      // raises a "Copied to…" toast.
      .onChange(of: router.sheet == nil) { _, closed in
        guard closed else { return }
        sheetClosedAt = .now
      }
      // A toast raised just before the app suspends would otherwise still be there on return,
      // then vanish at a moment unrelated to anything the person did.
      .onChange(of: scenePhase) { _, phase in
        guard phase != .active else { return }
        presenter.dismiss()
      }
  }

  /// `.announcement`, never `.screenChanged`: the latter moves VoiceOver focus, which for
  /// something transient strands the person somewhere they did not ask to be.
  ///
  /// A toast raised as a sheet closes — "Copied to…" — waits the sheet out, because VoiceOver
  /// moving back to the screen underneath would cut the announcement off.
  private func announceCurrent() async {
    guard let id = presenter.current?.id else { return }
    // SwiftUI does not promise to run the `.onChange` above before this task, so give it the
    // turn before reading its stamp.
    await Task.yield()
    let delay = ToastPresenter.announcementDelay(sinceSheetClosed: sheetClosedAt.map { .now - $0 })
    if delay > .zero {
      try? await Task.sleep(for: delay)
    }
    guard !Task.isCancelled, let toast = presenter.current, toast.id == id else { return }
    var announcement = AttributedString(String(localized: toast.message))
    announcement.accessibilitySpeechAnnouncementPriority = .high
    AccessibilityNotification.Announcement(announcement).post()
  }
}

extension View {
  /// Announces and times toasts for the whole app. Apply once, innermost at the app root; see
  /// `ChecklistsApp`.
  func toastPresenter() -> some View {
    modifier(ToastCoordinator())
  }

  /// Draws toasts over this screen while it is the frontmost one. Apply inside the screen's
  /// `NavigationStack`, so the bars are already outside its safe area.
  func toastOverlay(_ placement: ToastPlacement) -> some View {
    modifier(ToastOverlay(placement: placement))
  }
}
