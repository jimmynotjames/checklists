//
//  AnalyticsConsentSheet.swift
//  checklists
//

import SwiftUI

/// First-run analytics consent sheet, shown once in strict-opt-in jurisdictions on the first
/// pushed `checklist_viewed` (core-docs/analytics-spec.md §6.2) — see the trigger guard in
/// `ChecklistScreen`.
///
/// Accept and decline both route through `AnalyticsConsentController` so the ordering §6.3
/// requires is exercised by the same code the contract tests run against.
struct AnalyticsConsentSheet: View {
  @Environment(AnalyticsSettings.self) private var settings
  @Environment(\.analytics) private var analytics
  @Environment(\.dismiss) private var dismiss

  private var controller: AnalyticsConsentController {
    AnalyticsConsentController(settings: settings, analytics: analytics)
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        Spacer()

        Image(systemName: "chart.bar.doc.horizontal")
          .font(.system(size: 56))
          .foregroundStyle(Color.accentColor)
          .accessibilityHidden(true)

        VStack(spacing: 12) {
          Text("Help Improve the App?")
            .font(.title2.bold())

          Text("""
          This app can send anonymous usage data to help understand how it's used and fix \
          problems. Included: how often screens are opened, how many checklists and items you \
          have, the names of your checklists, error codes, and a random identifier for this \
          install — never linked to your Apple Account. Never included: item names, any notes, \
          or any Apple or iCloud identifiers. You can change this anytime in Settings.
          """)
          .font(.body)
          .foregroundStyle(Colors.inactiveTextColor)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)

        Spacer()

        VStack(spacing: 12) {
          Button {
            controller.accept()
            dismiss()
          } label: {
            Text("Share Anonymous Usage Data")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.glass)
          .controlSize(.large)
          .tint(Color.accentColor)
          .accessibilityIdentifier("analyticsConsentSheet.accept")
          .accessibilityLabel("Share Anonymous Usage Data")
          .accessibilityHint("Turns on anonymous usage data. No item names, notes, or Apple or iCloud identifiers are ever included.")

          Button {
            controller.decline()
            dismiss()
          } label: {
            Text("Not Now")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.glass)
          .controlSize(.large)
          .accessibilityIdentifier("analyticsConsentSheet.decline")
          .accessibilityLabel("Not Now")
          .accessibilityHint("Keeps anonymous usage data off. This can be changed later in Settings.")
        }
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 32)
      .appBackground()
      .navigationBarTitleDisplayMode(.inline)
    }
    // Swipe-to-dismiss is a decline (§6.3): without this, a swipe would leave the choice
    // unmade and the sheet would re-present on every checklist open.
    .onDisappear {
      if !settings.analyticsOptInExplicitlySet {
        controller.decline()
      }
    }
  }
}
