//
//  ToastPresenterModifier.swift
//  checklists
//

import SwiftUI

/// Draws whatever toast is up, and at the root also announces it and clears it on backgrounding.
///
/// Applied twice, because a `.sheet` is presented outside the root overlay's hierarchy and a toast
/// cannot be drawn over one from there: once at the root via `toastPresenter()`, and once on the
/// sheet's own content via `toastOverlay()`. Exactly one of the two draws at a time — the root
/// stands down while a sheet is up — so a toast is always visible wherever the person is looking,
/// and it is never announced or timed twice.
///
/// The main menu is *not* stood down for: it is a layer inside `RootView`'s `ZStack`, so the root
/// overlay already draws above it, and the card sits at the bottom while the menu's only control
/// is at the top.
private struct ToastLayer: ViewModifier {
  /// How far the card sits above the safe area on an ordinary screen.
  private static let bottomInset: CGFloat = 16

  /// Extra room for the floating add button on `ChecklistsView` — 60pt across with 20pt of
  /// padding, so 80pt of footprint — plus a little air. At `bottomInset` the card would lie over
  /// the button and swallow taps meant for it. In Edit mode the button is hidden and the bottom
  /// toolbar takes its place, which this also clears.
  private static let addButtonClearance: CGFloat = 88

  /// The root layer owns the announcement and the scene handling; the sheet's layer only draws,
  /// so neither fires twice.
  let isRoot: Bool

  @Environment(ToastPresenter.self) private var presenter
  @Environment(Router.self) private var router
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

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
          .padding(.bottom, bottomClearance)
          .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
      }
      // Value-scoped on purpose. `withAnimation` inside the presenter would be transaction-scoped
      // and animate every other change in the same update turn — the bug `MainMenuView` already
      // needed `Transaction(disablesAnimations: true)` to work around.
      .animation(.easeInOut(duration: 0.25), value: presenter.current?.id)
      // Keyed on the message, not the toast: a repeat of what is already up replaces the toast
      // but says nothing new, and VoiceOver should not read it twice.
      .onChange(of: announcedMessage) { _, _ in announceCurrent() }
      // A toast raised just before the app suspends would otherwise still be there on return,
      // then vanish at a moment unrelated to anything the person did.
      .onChange(of: scenePhase) { _, phase in
        guard isRoot, phase != .active else { return }
        presenter.dismiss()
      }
  }

  /// The add button belongs to `ChecklistsView`, which is what the card sits over exactly when
  /// nothing is pushed and no sheet is up. Measured from the safe area, which includes the
  /// keyboard, so with the keyboard up the card rides above it. `AnalyticsConsentSheet`'s
  /// Accept/Decline stack is taller than either value clears; a toast over it needs a third case.
  private var bottomClearance: CGFloat {
    isRoot && router.path.isEmpty ? Self.addButtonClearance : Self.bottomInset
  }

  /// Both layers key off the same condition, so exactly one ever draws. The sheet's half is not
  /// redundant: a dismissing sheet's content stays mounted for its slide-out, so a toast raised
  /// just after `dismiss()` would otherwise be drawn by both.
  private var drawsHere: Bool {
    isRoot ? router.sheet == nil : router.sheet != nil
  }

  private var announcedMessage: LocalizedStringResource? {
    isRoot ? presenter.current?.message : nil
  }

  /// `.announcement`, never `.screenChanged`: the latter moves VoiceOver focus, which for
  /// something transient strands the person somewhere they did not ask to be.
  private func announceCurrent() {
    guard isRoot, let toast = presenter.current else { return }
    var announcement = AttributedString(String(localized: toast.message))
    announcement.accessibilitySpeechAnnouncementPriority = .high
    AccessibilityNotification.Announcement(announcement).post()
  }
}

extension View {
  /// Applies the root toast layer. Apply once, innermost at the app root; see `ChecklistsApp`.
  func toastPresenter() -> some View {
    modifier(ToastLayer(isRoot: true))
  }

  /// Applies the toast layer to a sheet's content, which the root layer cannot draw over.
  func toastOverlay() -> some View {
    modifier(ToastLayer(isRoot: false))
  }
}
