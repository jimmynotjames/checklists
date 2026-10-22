//
//  ToastPresenterTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import Testing

/// Covers `ToastPresenter`'s display durations, announcement timing and its dismissal lifecycle.
///
/// Nothing here waits on a clock. The duration rule is pure, and the lifecycle is driven through
/// the injected `sleep`: one that suspends until cancelled holds a toast open, one that returns
/// immediately retires it on the next turn.
///
/// Messages are built from runtime strings rather than literals, so a test fixture is never
/// mistaken for copy needing translation.
///
/// `ToastLayer` is deliberately not covered — which of the two layers draws, the dismiss-versus-
/// action tap regions, and the VoiceOver announcement are all `ViewModifier` behaviour, and the
/// repo has no seam for that. `RatingPromptPresenter` is untested for the same reason; both keep
/// their decisions in a plain type instead, which is what this suite exercises. The tap-region
/// split in `ToastView` was verified on device.
@Suite("Toast presenter")
struct ToastPresenterTests {
  // MARK: - Fixtures

  private func message(_ text: String) -> LocalizedStringResource {
    LocalizedStringResource(String.LocalizationValue(stringLiteral: text))
  }

  private func toast(_ text: String, withAction: Bool = false) -> Toast {
    Toast(
      message: message(text),
      action: withAction ? ToastAction(title: message("Undo")) {} : nil
    )
  }

  /// A sleep that only ends when its task is cancelled, so a scheduled dismissal never fires
  /// while a test is looking. The hour is arbitrary — nothing waits it out.
  private func untilCancelled(_: Duration) async {
    try? await Task.sleep(for: .seconds(3600))
  }

  /// Yields until `isSatisfied`, bounded so a stuck expectation fails rather than hangs.
  private func settle(until isSatisfied: () -> Bool) async -> Bool {
    for _ in 0 ..< 100 {
      if isSatisfied() { return true }
      await Task.yield()
    }
    return isSatisfied()
  }

  // MARK: - Display duration

  @Test("an action toast stays up longer than a plain one")
  func actionToastStaysLonger() throws {
    let base = Duration.seconds(2)
    let plain = ToastPresenter.displayDuration(for: toast("copied"), base: base, isVoiceOverRunning: false)
    let withAction = try #require(ToastPresenter.displayDuration(
      for: toast("deleted", withAction: true),
      base: base,
      isVoiceOverRunning: false
    ))
    #expect(plain == base)
    #expect(withAction == ToastPresenter.actionDisplayDuration)
    #expect(withAction > base, "Reading the message, reaching the button and tapping it does not fit in the default dwell.")
  }

  @Test("nothing auto-dismisses while VoiceOver is running")
  func stickyUnderVoiceOver() {
    let duration = ToastPresenter.displayDuration(
      for: toast("copied"),
      base: .seconds(2),
      isVoiceOverRunning: true
    )
    #expect(duration == nil, "A transient timer races the announcement.")
  }

  // MARK: - Announcement timing

  @Test("a toast with no sheet closing is announced straight away")
  func announcedAtOnceWithoutASheet() {
    #expect(ToastPresenter.announcementDelay(sinceSheetClosed: nil) == .zero)
    #expect(ToastPresenter.announcementDelay(sinceSheetClosed: ToastPresenter.sheetDismissalAllowance) == .zero)
    #expect(ToastPresenter.announcementDelay(sinceSheetClosed: .seconds(30)) == .zero)
  }

  @Test("a toast raised as a sheet closes waits out the rest of the slide-out")
  func waitsOutAClosingSheet() {
    let allowance = ToastPresenter.sheetDismissalAllowance
    #expect(ToastPresenter.announcementDelay(sinceSheetClosed: .zero) == allowance)
    #expect(ToastPresenter.announcementDelay(sinceSheetClosed: .milliseconds(100)) == allowance - .milliseconds(100))
  }

  // MARK: - Lifecycle

  @Test("showing a toast puts it on screen")
  func showPresents() {
    let presenter = ToastPresenter(isVoiceOverRunning: { false }, sleep: untilCancelled)
    let shown = toast("copied")
    presenter.show(shown)
    #expect(presenter.current?.id == shown.id)
  }

  @Test("a later toast replaces the one on screen")
  func laterToastReplaces() {
    let presenter = ToastPresenter(isVoiceOverRunning: { false }, sleep: untilCancelled)
    presenter.show(toast("deleted"))
    let second = toast("duplicated")
    presenter.show(second)
    #expect(presenter.current?.id == second.id)
  }

  /// The order `ToastPresenterModifier` relies on when an action is tapped: it retires the tapped
  /// toast *before* running the handler, so a handler that raises its own toast — the shape a
  /// confirmed Undo takes — must not have it swallowed by that dismissal.
  @Test("a toast raised straight after a dismissal stays up")
  func showAfterDismissSurvives() async {
    let presenter = ToastPresenter(isVoiceOverRunning: { false }, sleep: untilCancelled)
    presenter.show(toast("deleted"))
    presenter.dismiss()
    let followUp = toast("restored")
    presenter.show(followUp)
    #expect(presenter.current?.id == followUp.id)
    // The retired toast's dismissal is still in flight; it must not take the new one with it.
    _ = await settle { presenter.current == nil }
    #expect(presenter.current?.id == followUp.id, "A dismissal in flight cleared the toast that replaced it.")
  }

  @Test("a toast retires itself when its dwell elapses")
  func autoDismisses() async {
    let presenter = ToastPresenter(isVoiceOverRunning: { false }, sleep: { _ in })
    presenter.show(toast("copied"))
    #expect(presenter.current != nil)
    #expect(await settle { presenter.current == nil }, "The dwell elapsed and the toast is still up.")
  }

  @Test("a toast stays put under VoiceOver even once its dwell would have elapsed")
  func doesNotAutoDismissUnderVoiceOver() async {
    let presenter = ToastPresenter(isVoiceOverRunning: { true }, sleep: { _ in })
    presenter.show(toast("copied"))
    // Gives any dismissal that was scheduled every chance to run; none should have been.
    _ = await settle { presenter.current == nil }
    #expect(presenter.current != nil, "A toast retired itself while VoiceOver was running.")
  }

  @Test("dismissing clears the toast")
  func dismissClears() {
    let presenter = ToastPresenter(isVoiceOverRunning: { false }, sleep: untilCancelled)
    presenter.show(toast("copied"))
    presenter.dismiss()
    #expect(presenter.current == nil)
  }
}
