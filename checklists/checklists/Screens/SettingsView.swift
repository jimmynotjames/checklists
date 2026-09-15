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
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(role: .close) {
            dismiss()
          }
          .tint(Color.accentColor)
        }
      }
      // Two independent `.task`s, each auto-cancelled by SwiftUI when the sheet is dismissed,
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
      Text("iCloud Sync")
    } footer: {
      iCloudFooter
    }
  }

  @ViewBuilder
  private var iCloudStatusRow: some View {
    switch syncStatus.rowState {
    case .checking:
      HStack {
        Text("Checking…")
        Spacer()
        ProgressView()
      }
      .accessibilityElement(children: .combine)

    case .available:
      Label {
        Text("iCloud Sync is Active")
      } icon: {
        Image(systemName: "checkmark.icloud")
          .foregroundStyle(Colors.successColor)
      }
      .accessibilityElement(children: .combine)

    case .paused:
      Label {
        Text("iCloud Sync Paused")
      } icon: {
        Image(systemName: "exclamationmark.icloud")
          .foregroundStyle(Colors.warningColor)
      }
      .accessibilityElement(children: .combine)

    case .unavailable:
      Label {
        Text("iCloud Not Available")
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
      Text("Sign in to iCloud in Settings to sync your checklists across devices.")
        .foregroundStyle(Colors.inactiveTextColor)
    case .paused:
      Text("Your checklists are saved on this device only. Restart the app to retry iCloud sync.")
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
        Text("Share Anonymous Usage Data")
      }
      .tint(Color.accentColor)
      .accessibilityHint("Allows the app to send anonymous usage data to help improve the app. No checklist item names, item notes, or Apple or iCloud identifiers are ever included.")
    } header: {
      Text("Diagnostics & Analytics")
    } footer: {
      Text("""
      Anonymous usage data helps troubleshoot issues and understand usage. Data is never linked to your \
      Apple Account. Never included: checklist item names, item notes, or any Apple or iCloud identifiers.
      """)
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
          Text("Privacy Policy")
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
      Text("Info")
    }
  }

  // MARK: - About section

  private var aboutSection: some View {
    Section {
      HStack {
        Text("Version")
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
