//
//  LoadingView.swift
//  checklists
//

import SwiftUI
import UIKit

/// Shown while the one-time copy out of the old Realm store runs.
///
/// Only ever appears on the single launch after an upgrade from a Realm build. Every other launch
/// installs the checklist list directly.
struct LoadingView: View {
  private let showsCloudSyncNote: Bool

  private let message = String(
    localized: "loading.message",
    defaultValue: "Migrating databases… need a moment…",
    comment: "Shown with a spinner on the one launch that copies data out of the pre-2025 database format.",
  )
  private let cloudSyncNote = String(
    localized: "loading.cloudSyncNote",
    defaultValue: "Your checklists will now sync across your devices through iCloud.",
    comment: "Footnote under the migration message when the migrated data will start syncing through iCloud.",
  )

  init(showsCloudSyncNote: Bool) {
    self.showsCloudSyncNote = showsCloudSyncNote
  }

  var body: some View {
    VStack(spacing: 16) {
      ProgressView()
        .controlSize(.large)
        // An indeterminate ProgressView stays system gray unless a tint is set explicitly; the
        // app-wide accent color alone does not reach it.
        .tint(Color.accentColor)

      Text(message)
        .font(.body)

      if showsCloudSyncNote {
        Text(cloudSyncNote)
          .font(.footnote)
          .foregroundStyle(Colors.inactiveTextColor)
      }
    }
    .multilineTextAlignment(.center)
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Colors.defaultBackgroundColor.ignoresSafeArea())
    .onAppear {
      // Nothing else on screen is interactive, and the user did not ask for this screen to appear —
      // an explicit announcement is the only way VoiceOver users learn a migration is in progress
      // rather than assuming the app hung.
      var announcement = message
      if showsCloudSyncNote {
        announcement += " " + cloudSyncNote
      }
      UIAccessibility.post(notification: .screenChanged, argument: announcement)
    }
  }
}

#if DEBUG
  #Preview("Migrating") {
    LoadingView(showsCloudSyncNote: false)
  }

  #Preview("Migrating with iCloud note") {
    LoadingView(showsCloudSyncNote: true)
  }
#endif
