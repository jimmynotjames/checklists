//
//  SyncStatusPresentation.swift
//  checklists
//

import Foundation

extension SyncStatus {
  /// What `SettingsView`'s iCloud row shows for a `RowState`: title, footer (`nil` when the state
  /// has none), the icon's SF Symbol name (`nil` only for `.checking`, which shows a spinner
  /// instead), and whether the icon reads as a warning. Kept on the model, not the view, so
  /// `SyncStatusTests` can assert every state deliberately — the
  /// `ContainerCreationFailure.allowsStoreReset` precedent (persistence-design.md §Sync status).
  struct RowPresentation: Equatable {
    let title: String
    let footer: String?
    let symbolName: String?
    let isWarning: Bool
  }

  var rowPresentation: RowPresentation {
    presentation(for: rowState)
  }

  /// Separated from `rowPresentation` so tests can assert a presentation for every `RowState`
  /// without also exercising `rowState`'s own derivation.
  ///
  /// The icon reuses `exclamationmark.icloud` (a transient, self-resolving problem) or
  /// `xmark.icloud` (needs an action outside the app) rather than introducing new symbol names —
  /// the approved copy doesn't specify iconography.
  func presentation(for state: RowState) -> RowPresentation {
    switch state {
    case .checking: checkingPresentation
    case .available: availablePresentation
    case .unavailable: unavailablePresentation
    case .paused: pausedPresentation
    case .restricted: restrictedPresentation
    case .needsAttention: needsAttentionPresentation
    case .couldNotCheck: couldNotCheckPresentation
    case .storageFull: storageFullPresentation
    case .syncInterrupted: syncInterruptedPresentation
    }
  }

  private var checkingPresentation: RowPresentation {
    RowPresentation(
      title: String(
        localized: "settings.icloud.checking",
        defaultValue: "Checking…",
        comment: "iCloud status row while the account status is still being looked up; shown next to a spinner."
      ),
      footer: nil,
      symbolName: nil,
      isWarning: false
    )
  }

  private var availablePresentation: RowPresentation {
    RowPresentation(
      title: String(
        localized: "settings.icloud.active",
        defaultValue: "iCloud Sync is Active",
        comment: "iCloud status row: checklists are syncing through iCloud."
      ),
      footer: lastSyncedFooter,
      symbolName: "checkmark.icloud",
      isWarning: false
    )
  }

  private var unavailablePresentation: RowPresentation {
    RowPresentation(
      title: String(
        localized: "settings.icloud.unavailable",
        defaultValue: "iCloud Not Available",
        comment: "iCloud status row: no iCloud account is signed in on this device."
      ),
      footer: String(
        localized: "settings.icloud.footer.unavailable",
        defaultValue: "Sign in to iCloud in Settings to sync your checklists across devices.",
        comment: "Footer under the iCloud section when no iCloud account is signed in. 'Settings' here means the iOS Settings app."
      ),
      symbolName: "xmark.icloud",
      isWarning: true
    )
  }

  private var pausedPresentation: RowPresentation {
    RowPresentation(
      title: String(
        localized: "settings.icloud.paused",
        defaultValue: "iCloud Sync Paused",
        comment: "iCloud status row: the app fell back to a local-only store this launch."
      ),
      footer: String(
        localized: "settings.icloud.footer.paused",
        defaultValue: "Your checklists are saved on this device only. Restart the app to retry iCloud sync.",
        comment: "Footer under the iCloud section when sync is paused for this launch."
      ),
      symbolName: "exclamationmark.icloud",
      isWarning: true
    )
  }

  private var restrictedPresentation: RowPresentation {
    RowPresentation(
      title: String(
        localized: "settings.icloud.restricted",
        defaultValue: "iCloud Restricted",
        comment: "iCloud status row: the account is signed in but restricted. Adjacent to 'settings.icloud.unavailable' (no account) and 'settings.icloud.needsAttention' (account needs attention) — keep distinct from both."
      ),
      footer: String(
        localized: "settings.icloud.footer.restricted",
        defaultValue: "iCloud is turned off on this device by Screen Time or your organization. Your checklists are saved on this device only.",
        comment: "Footer under the iCloud section when the iCloud account is restricted, e.g. by Screen Time or an organization's device management."
      ),
      symbolName: "xmark.icloud",
      isWarning: true
    )
  }

  private var needsAttentionPresentation: RowPresentation {
    RowPresentation(
      title: String(
        localized: "settings.icloud.needsAttention",
        defaultValue: "iCloud Needs Attention",
        comment: "iCloud status row: signed in but temporarily unavailable, e.g. needs Apple Account re-confirmation. Distinct from 'settings.icloud.restricted' — resolvable, not a standing restriction."
      ),
      footer: String(
        localized: "settings.icloud.footer.needsAttention",
        defaultValue: "Open Settings and confirm your Apple Account to resume syncing.",
        comment: "Footer under the iCloud section when the account is temporarily unavailable. 'Settings' here means the iOS Settings app."
      ),
      symbolName: "exclamationmark.icloud",
      isWarning: true
    )
  }

  private var couldNotCheckPresentation: RowPresentation {
    RowPresentation(
      title: String(
        localized: "settings.icloud.couldNotCheck",
        defaultValue: "Couldn't Check iCloud",
        comment: "iCloud status row: checking the account status failed, e.g. no network. Distinct from 'settings.icloud.unavailable' — a failed check, not a missing account."
      ),
      footer: String(
        localized: "settings.icloud.footer.couldNotCheck",
        defaultValue: "Check your internet connection. Your checklists are saved on this device.",
        comment: "Footer under the iCloud section when the account status couldn't be determined."
      ),
      symbolName: "exclamationmark.icloud",
      isWarning: true
    )
  }

  private var storageFullPresentation: RowPresentation {
    RowPresentation(
      title: String(
        localized: "settings.icloud.storageFull",
        defaultValue: "iCloud Storage Full",
        comment: "iCloud status row: a sync event failed because iCloud storage is full."
      ),
      footer: String(
        localized: "settings.icloud.footer.storageFull",
        defaultValue: "Free up iCloud storage in Settings to resume syncing. Your checklists are saved on this device.",
        comment: "Footer under the iCloud section when iCloud storage is full. 'Settings' here means the iOS Settings app."
      ),
      symbolName: "exclamationmark.icloud",
      isWarning: true
    )
  }

  private var syncInterruptedPresentation: RowPresentation {
    RowPresentation(
      title: String(
        localized: "settings.icloud.syncInterrupted",
        defaultValue: "iCloud Sync Interrupted",
        comment: "iCloud status row: a sync event failed for a reason other than storage. Distinct from 'settings.icloud.paused' — signed in and CloudKit-backed this launch, but a sync operation failed."
      ),
      footer: String(
        localized: "settings.icloud.footer.syncInterrupted",
        defaultValue: "Your checklists are saved on this device, and sync will keep retrying. If this doesn't clear up, send feedback from the menu.",
        comment: "Footer under the iCloud section when a sync operation failed for a reason other than storage."
      ),
      symbolName: "exclamationmark.icloud",
      isWarning: true
    )
  }

  /// `nil` until this launch's first recorded sync success, omitted rather than saying nothing
  /// synced. The most recent success across `setup`/`import`/`export`.
  private var lastSyncedFooter: String? {
    guard let lastSuccess = syncActivity.values.compactMap(\.lastSuccess).max() else { return nil }
    return String(
      localized: "settings.icloud.footer.lastSynced",
      defaultValue: "Last synced \(lastSuccess.formatted(.relative(presentation: .named)))",
      comment: "Footer under the iCloud section when sync is active; the placeholder is a relative time like '5 minutes ago'."
    )
  }
}
