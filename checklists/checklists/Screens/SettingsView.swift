//
//  SettingsView.swift
//  checklists
//

import CloudKit
import SwiftUI

/// Settings screen presented as a sheet from the app's `Router`. Mirrors budgets1's
/// `SettingsView` structure (Form + sections, `.task` loaders, `observeAccountChanges`
/// withTaskGroup pattern), but has no Themes section and none of the currency/week-start/
/// analytics-consent machinery budgets1 has.
struct SettingsView: View {
  @Environment(SyncStatus.self) private var syncStatus
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  var body: some View {
    NavigationStack {
      Form {
        iCloudSection
        infoSection
        aboutSection
      }
      .appBackground()
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
          .tint(Colors.tealColor) // iOS 26 Liquid Glass renders bar buttons monochrome without an explicit tint.
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
        AnalyticsManager.logSettingsViewed()
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

  // MARK: - Info section

  private var infoSection: some View {
    Section {
      Button {
        AnalyticsManager.logViewPrivacyPolicy()
        guard let url = URL(string: "https://www.termsfeed.com/privacy-policy/0420e699b562320b2beb80af0a4e08b9") else {
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
            .foregroundStyle(Colors.tealColor)
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
