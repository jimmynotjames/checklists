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
      // Independent `.task`s, each auto-cancelled by SwiftUI when the sheet is dismissed,
      // so there's no manual task lifecycle to start and stop here.
      .task {
        await ICloudStatusLoader().load(into: syncStatus)
      }
      .task {
        await observeAccountChanges()
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
    switch syncStatus.rowState {
    case .checking:
      HStack {
        Text(String(localized: "settings.icloud.checking", defaultValue: "Checking…", comment: "iCloud status row while the account status is still being looked up; shown next to a spinner."))
        Spacer()
        ProgressView()
      }
      .accessibilityElement(children: .combine)

    case .available:
      Label {
        Text(String(localized: "settings.icloud.active", defaultValue: "iCloud Sync is Active", comment: "iCloud status row: checklists are syncing through iCloud."))
      } icon: {
        Image(systemName: "checkmark.icloud")
          .foregroundStyle(Colors.successColor)
      }
      .accessibilityElement(children: .combine)

    case .paused:
      Label {
        Text(String(localized: "settings.icloud.paused", defaultValue: "iCloud Sync Paused", comment: "iCloud status row: the app fell back to a local-only store this launch."))
      } icon: {
        Image(systemName: "exclamationmark.icloud")
          .foregroundStyle(Colors.warningColor)
      }
      .accessibilityElement(children: .combine)

    case .unavailable:
      Label {
        Text(String(localized: "settings.icloud.unavailable", defaultValue: "iCloud Not Available", comment: "iCloud status row: no iCloud account is signed in on this device."))
      } icon: {
        Image(systemName: "xmark.icloud")
          .foregroundStyle(Colors.warningColor)
      }
      .accessibilityElement(children: .combine)
    }
  }

  @ViewBuilder
  private var iCloudFooter: some View {
    switch syncStatus.rowState {
    case .unavailable:
      Text(String(
        localized: "settings.icloud.footer.unavailable",
        defaultValue: "Sign in to iCloud in Settings to sync your checklists across devices.",
        comment: "Footer under the iCloud section when no iCloud account is signed in. 'Settings' here means the iOS Settings app."
      ))
      .foregroundStyle(Colors.inactiveTextColor)
    case .paused:
      Text(String(
        localized: "settings.icloud.footer.paused",
        defaultValue: "Your checklists are saved on this device only. Restart the app to retry iCloud sync.",
        comment: "Footer under the iCloud section when sync is paused for this launch."
      ))
      .foregroundStyle(Colors.inactiveTextColor)
    case .checking, .available:
      EmptyView()
    }
  }

  /// Observes iCloud account changes while Settings is on screen, so the row updates
  /// reactively without requiring a dismiss / re-open. Watches both `CKAccountChanged`
  /// (CloudKit container sign-in/out) and `NSUbiquityIdentityDidChange` (iCloud identity
  /// token rotation, e.g. an account switch in Settings.app) since either can fire
  /// independently.
  private func observeAccountChanges() async {
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await observeSingleNotification(.CKAccountChanged) }
      group.addTask { await observeSingleNotification(.NSUbiquityIdentityDidChange) }
    }
  }

  private func observeSingleNotification(_ name: NSNotification.Name) async {
    let notifications = NotificationCenter.default.notifications(named: name)
    for await _ in notifications {
      await ICloudStatusLoader().load(into: syncStatus)
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
      .previewEnvironment(syncStatus: PreviewSupport.syncStatus(containerBacking: .cloudKit, accountStatus: .unavailable))
  }

  #Preview("iCloud checking") {
    SettingsView()
      .previewEnvironment(syncStatus: PreviewSupport.syncStatus(containerBacking: .cloudKit, accountStatus: .checking))
  }
#endif
