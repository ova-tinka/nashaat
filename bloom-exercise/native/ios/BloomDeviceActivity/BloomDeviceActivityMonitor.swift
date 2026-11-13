import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

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
          defaults.bool(forKey: "bloom_blocking_active"),
          let end = defaults.object(forKey: "bloom_countdown_end") as? Date, end <= Date(),
          let data = defaults.data(forKey: "bloom_family_activity_selection"),
          let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
    let store = ManagedSettingsStore()
    store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    defaults.removeObject(forKey: "bloom_countdown_end")
  }
}
