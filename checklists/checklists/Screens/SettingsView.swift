//
//  SettingsView.swift
//  checklists
//

import CloudKit
import SwiftUI

/// Settings screen presented as a sheet from the app's `Router`.
struct SettingsView: View {
  @Environment(SyncStatus.self) private var syncStatus
  @Environment(AnalyticsSettings.self) private var settings
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @Environment(\.analytics) private var analytics

  var body: some View {
    NavigationStack {
      Form {
        iCloudSection
        analyticsSection
        infoSection
        aboutSection
      }
      .appBackground()
      .navigationTitle(CommonStrings.settingsTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(role: .close) {
            dismiss()
          }
          .tint(Color.accentColor)
        }
      }
      .task {
        analytics.track(AnalyticsEvent.settingsViewed)
      }
    }
  }

  // MARK: - iCloud section

  private var iCloudSection: some View {
    Section {
      iCloudStatusRow
    } header: {
      Text(String(localized: "settings.icloud.header", defaultValue: "iCloud Sync", comment: "Section header above the iCloud sync status row in Settings."))
    } footer: {
      iCloudFooter
    }
  }

  @ViewBuilder
  private var iCloudStatusRow: some View {
    let presentation = syncStatus.rowPresentation
    if let symbolName = presentation.symbolName {
      Label {
        Text(presentation.title)
      } icon: {
        Image(systemName: symbolName)
          .foregroundStyle(presentation.isWarning ? Colors.warningColor : Colors.successColor)
      }
      .accessibilityElement(children: .combine)
    } else {
      HStack {
        Text(presentation.title)
        Spacer()
        ProgressView()
      }
      .accessibilityElement(children: .combine)
    }
  }

  @ViewBuilder
  private var iCloudFooter: some View {
    if let footer = syncStatus.rowPresentation.footer {
      Text(footer)
        .foregroundStyle(Colors.inactiveTextColor)
    }
  }

  // MARK: - Analytics section

  private var analyticsSection: some View {
    Section {
      Toggle(isOn: Binding(
        get: { settings.analyticsOptIn },
        set: { newValue in
          AnalyticsConsentController(settings: settings, analytics: analytics).setOptIn(newValue)
        }
      )) {
        Text(String(localized: "settings.analytics.toggle", defaultValue: "Share Anonymous Usage Data", comment: "Label of the analytics opt-in toggle in Settings."))
      }
      .tint(Color.accentColor)
      .accessibilityHint(String(
        localized: "settings.analytics.toggle.hint",
        defaultValue: "Allows the app to send anonymous usage data to help improve the app. No checklist item names, item notes, or Apple or iCloud identifiers are ever included.",
        comment: "VoiceOver hint for the analytics opt-in toggle."
      ))
    } header: {
      Text(String(localized: "settings.analytics.header", defaultValue: "Diagnostics & Analytics", comment: "Section header above the analytics opt-in toggle in Settings."))
    } footer: {
      Text(String(
        localized: "settings.analytics.footer",
        defaultValue: "Anonymous usage data helps troubleshoot issues and understand usage. Data is never linked to your Apple Account. Never included: checklist item names, item notes, or any Apple or iCloud identifiers.",
        comment: "Footer under the analytics section explaining what usage data is and is not collected."
      ))
      .foregroundStyle(Colors.inactiveTextColor)
    }
  }

  // MARK: - Info section

  private var infoSection: some View {
    Section {
      Button {
        analytics.track(AnalyticsEvent.privacyPolicyTapped)
        guard let url = URL(string: "https://jimmynotjames.github.io/checklists/privacy.html") else {
          assertionFailure()
          return
        }
        openURL(url)
      } label: {
        Label {
          Text(String(localized: "settings.info.privacyPolicy", defaultValue: "Privacy Policy", comment: "Row in Settings that opens the app's privacy policy web page."))
            .foregroundStyle(.primary)
        } icon: {
          Image("PrivacyPolicyIcon25x25")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
            .foregroundStyle(Color.accentColor)
        }
      }
    } header: {
      // Title case, matching how the other Form headers here are written.
      Text(String(localized: "settings.info.header", defaultValue: "Info", comment: "Section header above the Privacy Policy row in Settings."))
    }
  }

  // MARK: - About section

  private var aboutSection: some View {
    Section {
      HStack {
        Text(String(localized: "settings.about.version", defaultValue: "Version", comment: "Label next to the app's version and build number in Settings."))
        Spacer()
        Text(verbatim: SettingsManager.versionBuildString)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      .accessibilityElement(children: .combine)
    }
  }
}

#if DEBUG
  #Preview("iCloud active") {
    SettingsView()
      .previewEnvironment(syncStatus: PreviewSupport.syncStatus(containerBacking: .cloudKit, accountStatus: .available))
  }

  #Preview("iCloud paused") {
    SettingsView()
      .previewEnvironment(syncStatus: PreviewSupport.syncStatus(containerBacking: .localFallback, accountStatus: .available))
  }

  #Preview("iCloud unavailable") {
    SettingsView()
      .previewEnvironment(syncStatus: PreviewSupport.syncStatus(containerBacking: .cloudKit, accountStatus: .noAccount))
  }

  #Preview("iCloud checking") {
    SettingsView()
      .previewEnvironment(syncStatus: PreviewSupport.syncStatus(containerBacking: .cloudKit, accountStatus: .checking))
  }

  #Preview("iCloud active, last synced") {
    SettingsView()
      .previewEnvironment(syncStatus: PreviewSupport.syncStatus(
        containerBacking: .cloudKit,
        accountStatus: .available,
        syncActivity: [.export: SyncOperationState(lastSuccess: .now.addingTimeInterval(-300), latestFailure: nil)]
      ))
  }

  #Preview("iCloud restricted") {
    SettingsView()
      .previewEnvironment(syncStatus: PreviewSupport.syncStatus(containerBacking: .cloudKit, accountStatus: .restricted))
  }

  #Preview("iCloud needs attention") {
    SettingsView()
      .previewEnvironment(syncStatus: PreviewSupport.syncStatus(containerBacking: .cloudKit, accountStatus: .temporarilyUnavailable))
  }

  #Preview("iCloud could not check") {
    SettingsView()
      .previewEnvironment(syncStatus: PreviewSupport.syncStatus(containerBacking: .cloudKit, accountStatus: .couldNotDetermine))
  }

  #Preview("iCloud storage full") {
    SettingsView()
      .previewEnvironment(syncStatus: PreviewSupport.syncStatus(
        containerBacking: .cloudKit,
        accountStatus: .available,
        syncActivity: [.export: SyncOperationState(lastSuccess: nil, latestFailure: SyncErrorCode(domain: CKErrorDomain, code: CKError.Code.quotaExceeded.rawValue))]
      ))
  }

  #Preview("iCloud sync interrupted") {
    SettingsView()
      .previewEnvironment(syncStatus: PreviewSupport.syncStatus(
        containerBacking: .cloudKit,
        accountStatus: .available,
        syncActivity: [.export: SyncOperationState(lastSuccess: nil, latestFailure: SyncErrorCode(domain: CKErrorDomain, code: CKError.Code.internalError.rawValue))]
      ))
  }
#endif
