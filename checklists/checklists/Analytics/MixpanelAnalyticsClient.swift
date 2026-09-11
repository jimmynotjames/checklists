//
//  MixpanelAnalyticsClient.swift
//  checklists
//

import Foundation
import Mixpanel
import UIKit

/// Production `AnalyticsClient` backed by the Mixpanel SDK.
///
/// **Lazy init is the consent guarantee (core-docs/analytics-spec.md §2's canonical constraint
/// #3, §7.2).** `Mixpanel.initialize` is never called from `init`. The SDK is created the first
/// time `track` reaches `ensureInitialized()` — which only happens from inside this class, never
/// gated here. Consent is `ConsentGatedAnalyticsClient`'s job: it wraps whichever client
/// `ChecklistsApp.makeAnalyticsClient()` returns and suppresses every call except `reset()` while
/// the person is opted out, so a `track` this class never sees can never initialize the SDK. This
/// client does **not** re-check opt-in itself — doing so would duplicate the gate rather than
/// trust it.
///
/// **Isolation:** `@unchecked Sendable` because `MixpanelInstance` does not declare `Sendable`,
/// which is what `AnalyticsClient: Sendable` requires. The target's
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` already makes every method below main-actor
/// isolated — there is no nonisolated context anywhere in this class, so `instanceLock` is not
/// covering a real race today. It stays because it is cheap and because isolation is a build
/// setting, not a language guarantee: if that setting ever changed, or a future call site called
/// in from a background queue, the lock is what would keep `ensureInitialized()` safe rather than
/// silently relying on the project-wide default. Marking any method here `nonisolated` to "prove"
/// the lock matters today would be a regression in its own right — it would let
/// `Mixpanel.initialize` run off the main thread, and the SDK's automatic-properties collection
/// touches UIKit (screen size, idiom) that assumes a main-thread caller.
final class MixpanelAnalyticsClient: AnalyticsClient, @unchecked Sendable {
  // MARK: - Stored state

  private let token: String
  /// Resolved once during `init()` rather than read from `ensureInitialized()`, so the actual
  /// `UIDevice.current` access happens exactly once regardless of how many times the SDK is
  /// lazily initialized across a reset → re-opt-in cycle.
  private let deviceClass: String
  private let distinctIdProvider: () -> String?

  /// Guards `_instance`. See the type-level isolation note above: redundant under the project's
  /// current default-MainActor isolation, kept as a correctness backstop rather than a load-bearing
  /// lock.
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

  /// Clears this client's own reference **and** the Mixpanel SDK's process-wide registry entry
  /// for `token` via `Mixpanel.removeInstance`. Dropping only `_instance` is not enough:
  /// `Mixpanel.initialize` registers every instance in a singleton keyed by its instance name
  /// (the token, since none is passed explicitly), which never releases it on its own. Without
  /// `removeInstance`, the opted-out install's `MixpanelInstance` would keep running — a
  /// foreground restarting its 60s flush timer, a background triggering `beginBackgroundTask` and
  /// a flush — for the rest of the process. The queue is empty by then, so nothing would actually
  /// leak out, but the instance would still be live and doing work it has no reason to do.
  func reset() {
    instanceLock.lock()
    _instance?.reset()
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

  /// Sets the `analytics_opt_in_at` people property (§9.3). No-op if the SDK has not yet been
  /// lazily initialized — which cannot happen on the opt-in path in practice, since the gate only
  /// lets this through once the flag has already flipped true, but a defensive no-op is cheaper
  /// than a precondition.
  func setAnalyticsOptInAt() {
    guard let instance = currentInstance() else { return }
    instance.people.set(properties: [AnalyticsProperty.analyticsOptInAt: Date()])
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
    // Conservative flush batch size — this app's event volume is small and there is no rush to
    // flush aggressively.
    newInstance.flushBatchSize = 50
    registerSuperProperties(on: newInstance)
    if let distinctId = distinctIdProvider() {
      newInstance.identify(distinctId: distinctId)
      setBaselinePeopleProperties(on: newInstance)
    }
    _instance = newInstance
    instanceLock.unlock()
    return newInstance
  }

  private func currentInstance() -> MixpanelInstance? {
    instanceLock.lock()
    defer { instanceLock.unlock() }
    return _instance
  }

  // MARK: - Private: super properties (§9.2)

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

  // MARK: - Private: people properties (§9.3)

  private func setBaselinePeopleProperties(on instance: MixpanelInstance) {
    let now = Date()
    instance.people.setOnce(properties: [AnalyticsProperty.firstSeenAt: now])
    instance.people.set(properties: [AnalyticsProperty.lastAppOpenAt: now])
  }
}
