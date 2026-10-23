//
//  MainMenuView.swift
//  checklists
//

import SwiftUI
import UIKit

/// Menu panel presented over the checklists list, offering feedback, App Store rating, and
/// settings actions. Full-screen on a narrow window, a side panel on a wide one (see `RootView`).
struct MainMenuView: View {
  @Environment(Router.self) private var router
  @Environment(SyncStatus.self) private var syncStatus
  @Environment(\.openURL) private var openURL
  @Environment(\.analytics) private var analytics

  /// The window controls' footprint at this panel's top-leading corner.
  /// Toolbar items step aside on their own, but this close button is plain content.
  @State private var windowControlsInset: CGSize = .zero

  /// VoiceOver starts on the close button rather than staying on the hidden ☰ behind the panel.
  @AccessibilityFocusState private var isCloseButtonFocused: Bool

  /// 21 is the `StopIcon` asset's size.
  private static let closeIconSlack: CGFloat = (44 - 21) / 2

  var body: some View {
    // The gap between menu rows lives here rather than in the rows themselves.
    VStack(alignment: .leading, spacing: 16) {
      Button {
        // The presenting view animates the dismissal.
        router.isMainMenuVisible = false
      } label: {
        Image("StopIcon")
          .foregroundStyle(Colors.defaultBackgroundColor)
          // The paddings below give back the slack on each side, so the icon draws where it did
          // and only the tappable area grows.
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel(String(localized: "mainMenu.close.accessibilityLabel", defaultValue: "Close menu", comment: "VoiceOver label for the X button that dismisses the main menu."))
      .accessibilityFocused($isCloseButtonFocused)
      .padding(.top, 8 - Self.closeIconSlack)
      // Never under the stock 16: a window without controls can still report a small corner inset
      // for its rounded corner.
      .padding(.leading, max(16, windowControlsInset.width + 8) - Self.closeIconSlack)
      // On top of the stack's own 16, so the close button reads as separate from the menu
      // rows rather than as a fourth item.
      .padding(.bottom, 8 - Self.closeIconSlack)

      // Rows scroll under the pinned close button once they outgrow the panel: as the landscape side
      // panel at the largest text sizes, three wrapped rows run taller than the screen.
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          MainMenuRow(
            title: String(localized: "mainMenu.feedback", defaultValue: "Feedback", comment: "Main-menu row that opens a pre-addressed feedback email."),
            iconName: "MainMenuFeedbackIcon",
          ) {
            analytics.track(AnalyticsEvent.feedbackTapped)
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = "jimmyho.appfeedback@gmail.com"
            components.queryItems = [
              URLQueryItem(
                name: "subject",
                value: String(
                  localized: "mainMenu.feedback.mail.subject",
                  defaultValue: "Feedback for reChecklist App",
                  comment: "Subject line of the feedback email opened from the main menu. Keep the app name reChecklist verbatim.",
                ),
              ),
              URLQueryItem(name: "body", value: feedbackBody),
            ]
            guard let url = components.url else { assertionFailure(); return }
            openURL(url)
          }

          MainMenuRow(
            title: String(localized: "mainMenu.rateInAppStore", defaultValue: "Rate in App Store", comment: "Main-menu row that opens the App Store review page."),
            iconName: "MainMenuRateInAppStoreIcon",
          ) {
            analytics.track(AnalyticsEvent.rateAppTapped)
            guard let url = URL(string: "https://itunes.apple.com/app/id1475724536?action=write-review")
            else { assertionFailure(); return }
            openURL(url)
          }

          MainMenuRow(
            title: CommonStrings.settingsTitle,
            iconName: "MainMenuSettingsIcon",
          ) {
            // The menu must vanish instantly here so it isn't still animating out behind the
            // Settings sheet coming up.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
              router.isMainMenuVisible = false
            }
            router.sheet = .settings
          }
          // Locale-invariant handle for the localized large-type check.
          .accessibilityIdentifier("mainMenu.settings")
        }
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .onGeometryChange(for: CGSize.self) { $0.containerCornerInsets.topLeading } action: {
      windowControlsInset = $0
    }
    .background(Colors.darkBlueGrayColor.ignoresSafeArea())
    // As a side panel the list stays on screen beside it; VoiceOver must not wander into it. The
    // trait needs a container to apply to, or SwiftUI hands it down to each row.
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
    // The two-finger scrub that closes any other panel.
    .accessibilityAction(.escape) {
      router.isMainMenuVisible = false
    }
    .task {
      analytics.track(AnalyticsEvent.mainMenuViewed)
    }
    .task {
      // After the slide-in, or the button isn't on screen yet to take focus.
      try? await Task.sleep(for: .seconds(RootView.menuAnimationSeconds + 0.1))
      isCloseButtonFocused = true
    }
  }

  /// Two blank lines above the diagnostics, for whatever the person types first. English only,
  /// not localized — it's for reading, not sending.
  private var feedbackBody: String {
    let report = SyncDiagnostics.report(
      syncStatus: syncStatus,
      appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0",
      build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0",
      osVersion: UIDevice.current.systemVersion,
    )
    return "\n\n\n\(report)"
  }
}

/// One row of the main menu: a full-width tap target pairing an icon with a title.
private struct MainMenuRow: View {
  let title: String
  let iconName: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        // The title carries the meaning. Otherwise the icon is an image element of its own, named
        // after its asset.
        Image(decorative: iconName)
          .resizable()
          .scaledToFit()
          .frame(width: 44, height: 44)

        Text(title)
          .font(.title2.weight(.medium))
          .foregroundStyle(Colors.defaultBackgroundColor)

        Spacer()
      }
      .padding(.leading, 16)
      // The row is exactly as tall as its content: the 44pt icon, or the title once large
      // Dynamic Type sizes make it taller. 44 is also the minimum comfortable tap target.
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

#if DEBUG
  #Preview("Main menu") {
    MainMenuView()
      .environment(PreviewSupport.router)
      .environment(PreviewSupport.syncStatus())
  }

  #Preview("Row") {
    MainMenuRow(title: "Settings", iconName: "MainMenuSettingsIcon") {}
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(Colors.darkBlueGrayColor.ignoresSafeArea())
  }
#endif
