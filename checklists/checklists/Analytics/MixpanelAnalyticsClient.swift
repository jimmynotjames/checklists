//
//  MixpanelAnalyticsClient.swift
//  checklists
//

import Foundation
import Mixpanel
import UIKit

/// Production `AnalyticsClient` backed by the Mixpanel SDK.
///
/// **Lazy init is the consent guarantee**: `Mixpanel.initialize` is never called from `init`,
/// only from `ensureInitialized()`, and `ConsentGatedAnalyticsClient` keeps opted-out calls from
/// ever reaching it — so this class never checks opt-in itself.
///
/// **Isolation:** `@unchecked Sendable` because `MixpanelInstance` isn't `Sendable`. `instanceLock`
/// is a backstop, not load-bearing under the target's MainActor default — keep it rather than
/// prove it unnecessary. Never mark a method here `nonisolated`: `Mixpanel.initialize` touches UIKit.
final class MixpanelAnalyticsClient: AnalyticsClient, @unchecked Sendable {
  // MARK: - Stored state

  private let token: String
  /// Resolved once during `init()` rather than read from `ensureInitialized()`, so the actual
  /// `UIDevice.current` access happens exactly once regardless of how many times the SDK is
  /// lazily initialized across a reset → re-opt-in cycle.
  private let deviceClass: String
  private let distinctIdProvider: () -> String?

  /// Guards `_instance`.
  private let instanceLock = NSLock()
  /// The lazily-created SDK instance. `nil` until the first `track` after opt-in.
  private var _instance: MixpanelInstance?

  // MARK: - Init

  /// Creates a client. The Mixpanel SDK is **not** initialized here.
  ///
  /// - Parameters:
  ///   - token: The Mixpanel project token for the active build configuration
  ///     (`MixpanelTokenSource.activeToken`).
  ///   - distinctIdProvider: Returns the stable `AnalyticsSettings.analyticsDistinctId`.
  @MainActor
  init(token: String, distinctIdProvider: @escaping () -> String?) {
    self.token = token
    deviceClass = switch UIDevice.current.userInterfaceIdiom {
    case .phone: "phone"
    case .pad: "pad"
    case .mac: "mac"
    default: "phone"
    }
    self.distinctIdProvider = distinctIdProvider
  }

  // MARK: - AnalyticsClient

  func track(_ event: String, properties: [String: any Sendable]?) {
    let instance = ensureInitialized()
    if event == AnalyticsEvent.appOpened {
      instance.people.set(properties: [AnalyticsProperty.lastAppOpenAt: Date()])
    }
    let mixProps = properties?.compactMapValues { $0 as? MixpanelType }
    instance.track(event: event, properties: mixProps)
  }

  func identify(_ distinctId: String?) {
    // Checked before `ensureInitialized()`, not after: there is no production caller that passes
    // `nil` today, but a `nil` must not construct an SDK instance it then does nothing with.
    guard let id = distinctId else { return }
    let instance = ensureInitialized()
    instance.identify(distinctId: id)
  }

  /// Opts out through the SDK's own `optOutTracking()`: it deletes the Mixpanel profile, persists
  /// the opt-out in the SDK's storage, and stops every later send. Anything still queued stays on
  /// disk unsent, and goes out only if the person opts back in.
  ///
  /// Then clears this client's reference **and** the SDK's process-wide registry entry via
  /// `Mixpanel.removeInstance` — `Mixpanel.initialize` keeps every instance alive in a singleton
  /// keyed by token, so without this an opted-out install's instance stays resident.
  func reset() {
    instanceLock.lock()
    _instance?.optOutTracking()
    Mixpanel.removeInstance(name: token)
    _instance = nil
    instanceLock.unlock()
  }

  func refreshSuperProperties() {
    guard let instance = currentInstance() else { return }
    registerSuperProperties(on: instance)
  }

  func refreshCohortPeopleProperties(checklistsCount: Int) {
    guard let instance = currentInstance() else { return }
    instance.people.set(properties: [
      AnalyticsProperty.checklistsCountBucket: checklistsCountBucket(checklistsCount),
    ])
  }

  func setAnalyticsOptInAt() {
    guard let instance = currentInstance() else { return }
    instance.people.set(properties: [AnalyticsProperty.analyticsOptInAt: Date()])
  }

  func setRatingPromptFirstEligibleAt(_ date: Date) {
    guard let instance = currentInstance() else { return }
    instance.people.set(properties: [AnalyticsProperty.ratingPromptFirstEligibleAt: date])
  }

  func setRatingPromptLastRequestedAt(_ date: Date) {
    guard let instance = currentInstance() else { return }
    instance.people.set(properties: [AnalyticsProperty.ratingPromptLastRequestedAt: date])
  }

  // MARK: - Private: lazy init

  #if DEBUG
    /// Test-only seam for `MixpanelClientGateTests` to observe whether the SDK has been
    /// initialized, without exposing `MixpanelInstance` itself.
    var isSDKInitializedForTesting: Bool {
      currentInstance() != nil
    }
  #endif

  @discardableResult
  private func ensureInitialized() -> MixpanelInstance {
    instanceLock.lock()
    if let existing = _instance {
      instanceLock.unlock()
      return existing
    }
    let newInstance = Mixpanel.initialize(token: token, trackAutomaticEvents: false)
    // Defaults to `true`, which sends `ip=1` and has Mixpanel derive `$city` / `$region` from the
    // request IP. This app's location signal is the device's own `locale` / `region` settings, so
    // the derived geolocation is turned off rather than declared. `MixpanelOptions` has no
    // parameter for it.
    newInstance.useIPAddressForGeoLocation = false
    // Conservative flush batch size — this app's event volume is small and there is no rush to
    // flush aggressively.
    newInstance.flushBatchSize = 50
    registerSuperProperties(on: newInstance)
    // Only an opted-in caller reaches here, so a persisted SDK opt-out from an earlier `reset()` is
    // stale. `optInTracking` clears it asynchronously and identifies on its own queue; the SDK drops
    // people updates made before that lands, so the baseline ones wait for the next init.
    if newInstance.hasOptedOutTracking() {
      newInstance.optInTracking(distinctId: distinctIdProvider())
    } else if let distinctId = distinctIdProvider() {
      newInstance.identify(distinctId: distinctId)
      setBaselinePeopleProperties(on: newInstance)
    }
    _instance = newInstance
    instanceLock.unlock()
    return newInstance
  }

  /// The instance if the SDK is already up, without initializing it. The people-property setters
  /// go through this, so they never open a connection on their own; in practice each follows a
  /// `track` that has already initialized the SDK.
  private func currentInstance() -> MixpanelInstance? {
    instanceLock.lock()
    defer { instanceLock.unlock() }
    return _instance
  }

  // MARK: - Private: super properties

  private func registerSuperProperties(on instance: MixpanelInstance) {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    let localeId = Locale.current.identifier
    let regionId = Locale.current.region?.identifier ?? ""
    let jurisdiction: String =
      ConsentJurisdiction.kind(for: Locale.current.region?.identifier) == .required
        ? "required" : "auto_optin"

    let props: [String: MixpanelType] = [
      AnalyticsProperty.appVersion: version,
      AnalyticsProperty.appBuild: build,
      AnalyticsProperty.deviceClass: deviceClass,
      AnalyticsProperty.locale: localeId,
      AnalyticsProperty.region: regionId,
      AnalyticsProperty.consentJurisdiction: jurisdiction,
    ]
    instance.registerSuperProperties(props)
  }

  // MARK: - Private: people properties

  private func setBaselinePeopleProperties(on instance: MixpanelInstance) {
    let now = Date()
    instance.people.setOnce(properties: [AnalyticsProperty.firstSeenAt: now])
    instance.people.set(properties: [AnalyticsProperty.lastAppOpenAt: now])
  }
}
