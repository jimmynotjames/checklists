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

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        // The presenting view animates the dismissal.
        router.isMainMenuVisible = false
      } label: {
        Image("StopIcon")
          .foregroundStyle(Colors.defaultBackgroundColor)
      }
      .accessibilityLabel("Close menu")
      .padding(.top, 8)
      .padding(.leading, 16)

      MainMenuRow(title: "Feedback", iconName: "MainMenuFeedbackIcon") {
        AnalyticsManager.logSendFeedback()
        guard let url = URL(string: "mailto:jimmyho.appfeedback@gmail.com?subject=Feedback%20for%20reChecklist%20App")
        else { assertionFailure(); return }
        openURL(url)
      }

      MainMenuRow(title: "Rate in App Store", iconName: "MainMenuRateInAppStoreIcon") {
        AnalyticsManager.logRateInAppStore()
        guard let url = URL(string: "https://itunes.apple.com/app/id1475724536?action=write-review")
        else { assertionFailure(); return }
        openURL(url)
      }

      MainMenuRow(title: "Settings", iconName: "MainMenuSettingsIcon") {
        // The menu must vanish instantly here so it isn't still animating out behind the
        // Settings sheet coming up.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
          router.isMainMenuVisible = false
        }
        router.sheet = .settings
      }

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Colors.darkBlueGrayColor.ignoresSafeArea())
    .task {
      AnalyticsManager.logMainMenuViewed()
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
      // Minimum, not fixed: text at large Dynamic Type sizes can grow the row instead of
      // clipping.
      .frame(minHeight: 60)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
