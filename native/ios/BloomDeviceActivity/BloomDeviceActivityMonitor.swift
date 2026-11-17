import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import SafariServices

/// Runs in a system-managed extension, including while the Bloom app is closed.
final class BloomDeviceActivityMonitor: DeviceActivityMonitor {
  private let countdownName = DeviceActivityName("bloom.countdown.expiry")

  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    if activity.rawValue.hasPrefix("bloom.usage.expiry.") { finishExpired(activity); return }
    guard activity == countdownName else { return }
    restoreShields()
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    if activity.rawValue.hasPrefix("bloom.usage.expiry.") { finishExpired(activity); return }
    guard activity == countdownName else { return }
    restoreShields()
  }

  override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
    super.eventDidReachThreshold(event, activity: activity)
    // Easy accounting is based on the database-timed access window. Usage
    // thresholds do not measure foreground access or control its duration.
  }

  private func finishExpired(_ activity: DeviceActivityName) {
    do {
      try BloomUsageFile.shared().mutate { state in
        guard var current = state, activity.rawValue == "bloom.usage.expiry.\(current.sessionId)", !current.closed,
              current.expiry <= Date() else { return }
        current.refresh(now: Date())
        if !current.closed { current.finish(now: Date()) }
        restoreUsageShields()
        state = current
      }
    } catch { restoreUsageShields() }
  }

  private func restoreUsageShields() {
    setSafariFocusSuspended(false)
    guard let group = Bundle.main.object(forInfoDictionaryKey: "BloomAppGroup") as? String,
          let defaults = UserDefaults(suiteName: group), defaults.bool(forKey: "bloom_blocking_active"),
          let data = defaults.data(forKey: "bloom_family_activity_selection"),
          let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
    let store = ManagedSettingsStore()
    store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
  }

  private func restoreShields() {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "BloomAppGroup") as? String,
          let defaults = UserDefaults(suiteName: group),
          let end = defaults.object(forKey: "bloom_countdown_end") as? Date, end <= Date() else { return }
    defer {
      setSafariFocusSuspended(false)
      defaults.removeObject(forKey: "bloom_countdown_end")
    }
    guard defaults.bool(forKey: "bloom_blocking_active"),
          let data = defaults.data(forKey: "bloom_family_activity_selection"),
          let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
    let store = ManagedSettingsStore()
    store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
  }

  private func setSafariFocusSuspended(_ suspended: Bool) {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "BloomAppGroup") as? String,
          let defaults = UserDefaults(suiteName: group) else { return }
    let key = "bloom_safari_focus_suspended"
    let changed = defaults.bool(forKey: key) != suspended
    defaults.set(suspended, forKey: key)
    guard changed,
          let identifier = Bundle.main.bundleIdentifier,
          identifier.hasSuffix(".DeviceActivityMonitorExtension") else { return }
    let appIdentifier = String(identifier.dropLast(".DeviceActivityMonitorExtension".count))
    SFContentBlockerManager.reloadContentBlocker(withIdentifier: appIdentifier + ".SafariContentBlocker") { _ in }
  }
}
