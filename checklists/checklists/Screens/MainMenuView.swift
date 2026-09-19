//
//  MainMenuView.swift
//  checklists
//

import SwiftUI

/// Full-screen menu panel presented over the checklists list, offering feedback, App Store
/// rating, and settings actions.
struct MainMenuView: View {
  @Environment(Router.self) private var router
  @Environment(\.openURL) private var openURL
  @Environment(\.analytics) private var analytics

  var body: some View {
    // The gap between menu rows lives here rather than in the rows themselves.
    VStack(alignment: .leading, spacing: 16) {
      Button {
        // The presenting view animates the dismissal.
        router.isMainMenuVisible = false
      } label: {
        Image("StopIcon")
          .foregroundStyle(Colors.defaultBackgroundColor)
      }
      .accessibilityLabel(String(localized: "mainMenu.close.accessibilityLabel", defaultValue: "Close menu", comment: "VoiceOver label for the X button that dismisses the main menu."))
      .padding(.top, 8)
      .padding(.leading, 16)
      // On top of the stack's own 16, so the close button reads as separate from the menu
      // rows rather than as a fourth item.
      .padding(.bottom, 8)

      MainMenuRow(
        title: String(localized: "mainMenu.feedback", defaultValue: "Feedback", comment: "Main-menu row that opens a pre-addressed feedback email."),
        iconName: "MainMenuFeedbackIcon"
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
              comment: "Subject line of the feedback email opened from the main menu. Keep the app name reChecklist verbatim."
            )
          ),
        ]
        guard let url = components.url else { assertionFailure(); return }
        openURL(url)
      }

      MainMenuRow(
        title: String(localized: "mainMenu.rateInAppStore", defaultValue: "Rate in App Store", comment: "Main-menu row that opens the App Store review page."),
        iconName: "MainMenuRateInAppStoreIcon"
      ) {
        analytics.track(AnalyticsEvent.rateAppTapped)
        guard let url = URL(string: "https://itunes.apple.com/app/id1475724536?action=write-review")
        else { assertionFailure(); return }
        openURL(url)
      }

      MainMenuRow(
        title: String(localized: "common.settings.title", defaultValue: "Settings", comment: "Title of the Settings screen and the main-menu row that opens it."),
        iconName: "MainMenuSettingsIcon"
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

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Colors.darkBlueGrayColor.ignoresSafeArea())
    .task {
      analytics.track(AnalyticsEvent.mainMenuViewed)
    }
  }
}

/// One row of the main menu: a fixed-height, full-width tap target pairing an icon with a title.
private struct MainMenuRow: View {
  let title: String
  let iconName: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(iconName)
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
  }

  #Preview("Row") {
    MainMenuRow(title: "Settings", iconName: "MainMenuSettingsIcon") {}
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(Colors.darkBlueGrayColor.ignoresSafeArea())
  }
#endif
