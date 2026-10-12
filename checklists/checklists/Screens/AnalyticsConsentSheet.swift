//
//  AnalyticsConsentSheet.swift
//  checklists
//

import SwiftUI

/// First-run analytics consent sheet, shown once in strict-opt-in jurisdictions on the first
/// pushed `checklist_viewed` (`analytics-spec.md §Strict-opt-in jurisdictions`) — see the trigger
/// guard in `ChecklistScreen`.
///
/// Accept and decline both route through `AnalyticsConsentController` so the ordering
/// `analytics-spec.md §Toggle-off behaviour` requires is exercised by the same code the contract tests run against.
struct AnalyticsConsentSheet: View {
  @Environment(AnalyticsSettings.self) private var settings
  @Environment(\.analytics) private var analytics
  @Environment(\.dismiss) private var dismiss

  private var controller: AnalyticsConsentController {
    AnalyticsConsentController(settings: settings, analytics: analytics)
  }

  private static let acceptTitle = String(
    localized: "consent.action.accept",
    defaultValue: "Share Anonymous Usage Data",
    comment: "Accept button on the analytics consent sheet; turns anonymous usage data on."
  )

  private static let declineTitle = String(
    localized: "consent.action.decline",
    defaultValue: "Not Now",
    comment: "Decline button on the analytics consent sheet; keeps usage data off."
  )

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          Image(systemName: "chart.bar.doc.horizontal")
            .font(.system(size: 56))
            .foregroundStyle(Color.accentColor)
            .accessibilityHidden(true)

          VStack(spacing: 12) {
            Text(String(localized: "consent.title", defaultValue: "Help Improve the App?", comment: "Title of the one-time analytics consent sheet."))
              .font(.title2.bold())

            Text(String(
              localized: "consent.body",
              defaultValue: """
              This app can send anonymous usage data that helps troubleshoot issues and understand usage. \
              Data is never linked to your Apple Account. Never included: checklist item names, \
              item notes, or any Apple or iCloud identifiers. You can change this anytime in Settings.
              """,
              comment: "Body of the analytics consent sheet explaining what is and is not collected."
            ))
            .font(.body)
            .foregroundStyle(Colors.inactiveTextColor)
          }
          .multilineTextAlignment(.center)
          .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 24)
      }
      // Centred in the space above the buttons while it fits; past that it scrolls from the top.
      .defaultScrollAnchor(.center, for: .alignment)
      .scrollBounceBehavior(.basedOnSize)
      // Pinned below the scrolling text, so both choices stay on screen at every text size; at the
      // largest sizes the text scrolls under them.
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: 12) {
          Button {
            controller.accept()
            dismiss()
          } label: {
            Text(Self.acceptTitle)
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.glass)
          .controlSize(.large)
          .tint(Color.accentColor)
          .accessibilityIdentifier("analyticsConsentSheet.accept")
          .accessibilityLabel(Self.acceptTitle)
          .accessibilityHint(String(
            localized: "consent.action.accept.hint",
            defaultValue: "Turns on anonymous usage data to help improve the app. No checklist item names, item notes, or Apple or iCloud identifiers are ever included.",
            comment: "VoiceOver hint for the accept button on the analytics consent sheet."
          ))

          Button {
            controller.decline()
            dismiss()
          } label: {
            Text(Self.declineTitle)
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.glass)
          .controlSize(.large)
          .accessibilityIdentifier("analyticsConsentSheet.decline")
          .accessibilityLabel(Self.declineTitle)
          .accessibilityHint(String(
            localized: "consent.action.decline.hint",
            defaultValue: "Keeps anonymous usage data off. This can be changed later in Settings.",
            comment: "VoiceOver hint for the decline button on the analytics consent sheet."
          ))
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(Colors.defaultBackgroundColor.ignoresSafeArea())
      }
      .appBackground()
      .navigationBarTitleDisplayMode(.inline)
    }
    // Swipe-to-dismiss is a decline (`analytics-spec.md §Toggle-off behaviour`): without this, a swipe would leave the choice
    // unmade and the sheet would re-present on every checklist open.
    .onDisappear {
      if !settings.analyticsOptInExplicitlySet {
        controller.decline()
      }
    }
  }
}

#if DEBUG
  #Preview("Consent") {
    AnalyticsConsentSheet()
      .environment(PreviewSupport.analyticsSettings)
  }
#endif
