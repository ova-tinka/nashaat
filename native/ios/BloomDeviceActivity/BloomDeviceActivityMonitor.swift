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
    if activity.rawValue.hasPrefix("bloom.sched.") { applyScheduled(activity); return }
    guard activity == countdownName else { return }
    restoreShields()
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    if activity.rawValue.hasPrefix("bloom.usage.expiry.") { finishExpired(activity); return }
    if activity.rawValue.hasPrefix("bloom.sched.") { clearScheduled(activity); return }
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

  private func applyScheduled(_ activity: DeviceActivityName) {
    guard let (account, routineId) = scheduledParts(activity),
          let group = Bundle.main.object(forInfoDictionaryKey: "BloomAppGroup") as? String,
          let defaults = UserDefaults(suiteName: group),
          defaults.string(forKey: "bloom_scheduled_focus_account") == account,
          let data = defaults.data(forKey: "bloom_scheduled_focus_routines:" + account),
          let routines = try? JSONDecoder().decode([ScheduledFocusRoutine].self, from: data),
          let routine = routines.first(where: { $0.id == routineId && $0.enabled }),
          isActive(routine) else {
      if let (account, routineId) = scheduledParts(activity) { clearScheduledStore(account, routineId) }
      return
    }
    let selectionKey = "bloom_scheduled_focus_selection:" + account + ":" + routineId
    guard let selectionData = defaults.data(forKey: selectionKey),
          let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData) else {
      clearScheduledStore(account, routineId)
      return
    }
    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("bloom.sched." + account + "." + routineId))
    store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
  }

  private func clearScheduled(_ activity: DeviceActivityName) {
    guard let (account, routineId) = scheduledParts(activity) else { return }
    clearScheduledStore(account, routineId)
  }

  private func scheduledParts(_ activity: DeviceActivityName) -> (String, String)? {
    let parts = activity.rawValue.split(separator: ".")
    guard parts.count == 5, parts[0] == "bloom", parts[1] == "sched",
          UUID(uuidString: String(parts[2])) != nil, UUID(uuidString: String(parts[3])) != nil,
          Int(parts[4]) != nil else { return nil }
    return (String(parts[2]), String(parts[3]))
  }

  private func clearScheduledStore(_ account: String, _ routineId: String) {
    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("bloom.sched." + account + "." + routineId))
    store.shield.applications = nil
    store.shield.applicationCategories = nil
    store.shield.webDomains = nil
    store.shield.webDomainCategories = nil
  }

  private struct ScheduledFocusRoutine: Decodable {
    let id: String
    let enabled: Bool
    let startMinute: Int
    let endMinute: Int
    let days: [Int]
  }

  private func isActive(_ routine: ScheduledFocusRoutine, now: Date = Date()) -> Bool {
    let calendar = Calendar.current
    let day = calendar.component(.weekday, from: now) - 1
    let minute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
    if routine.startMinute < routine.endMinute {
      return routine.days.contains(day) && minute >= routine.startMinute && minute < routine.endMinute
    }
    return (routine.days.contains(day) && minute >= routine.startMinute)
      || (routine.days.contains((day + 6) % 7) && minute < routine.endMinute)
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
