import Foundation

struct MacWebsiteUsageAccess {
  static func allows(host: String, activeHost: String?, targetHeartbeatMillis: Double?, targetBoot: Int64?,
                     nowMillis: Double, boot: Int64?, state: MacUsageState?, configuration: [String: Any]?) -> Bool {
    let rules = WebsiteRules(configuration: configuration)
    guard rules.blocks(host), let activeHost, rules.blocks(activeHost),
          let targetHeartbeatMillis, targetHeartbeatMillis.isFinite,
          nowMillis.isFinite, nowMillis >= targetHeartbeatMillis,
          nowMillis - targetHeartbeatMillis <= 5000,
          let boot, boot > 0, targetBoot == boot,
          let state else { return false }
    return state.allows(now: nowMillis, boot: boot)
  }

  static func allowsUnknownBrowser(bundleIdentifier: String, activeBrowserIdentifier: String?, targetHeartbeatMillis: Double?, targetBoot: Int64?,
                                   nowMillis: Double, boot: Int64?, state: MacUsageState?, configuration: [String: Any]?) -> Bool {
    guard !WebsiteRules(configuration: configuration).isEmpty,
          activeBrowserIdentifier == bundleIdentifier,
          let targetHeartbeatMillis, targetHeartbeatMillis.isFinite,
          nowMillis.isFinite, nowMillis >= targetHeartbeatMillis,
          nowMillis - targetHeartbeatMillis <= 5000,
          let boot, boot > 0, targetBoot == boot,
          let state else { return false }
    return state.allows(now: nowMillis, boot: boot)
  }

  static func allows(host: String, configuration: [String: Any]?) -> Bool {
    guard let group = BloomAppGroup.identifier,
          let defaults = UserDefaults(suiteName: group),
          let state = try? MacUsageStore.shared().readSnapshot(),
          let boot = FilterCreditClock.boot() else { return false }
    return allows(host: host,
      activeHost: defaults.string(forKey: "usageTargetDomain"),
      targetHeartbeatMillis: (defaults.object(forKey: "usageTargetHeartbeatMillis") as? NSNumber)?.doubleValue,
      targetBoot: (defaults.object(forKey: "usageTargetBoot") as? NSNumber)?.int64Value,
      nowMillis: FilterCreditClock.nowMillis(), boot: boot, state: state, configuration: configuration)
  }

  static func allows(host: String, userID: UInt32?, configuration: [String: Any]?) -> Bool {
    guard let userID, let boot = FilterCreditClock.boot(),
          let snapshot = MacPolicyBrokerClient.shared.snapshot(for: userID,
            nowMillis: FilterCreditClock.nowMillis(), boot: boot) else { return false }
    return snapshot.allowsWebsiteUsage(host: host, browserIdentifier: nil,
      nowMillis: FilterCreditClock.nowMillis(), boot: boot, configuration: configuration)
  }

  static func allowsUnknownBrowser(bundleIdentifier: String, configuration: [String: Any]?) -> Bool {
    guard let group = BloomAppGroup.identifier,
          let defaults = UserDefaults(suiteName: group),
          let state = try? MacUsageStore.shared().readSnapshot(),
          let boot = FilterCreditClock.boot() else { return false }
    return allowsUnknownBrowser(bundleIdentifier: bundleIdentifier,
      activeBrowserIdentifier: defaults.string(forKey: "usageTargetBrowser"),
      targetHeartbeatMillis: (defaults.object(forKey: "usageTargetHeartbeatMillis") as? NSNumber)?.doubleValue,
      targetBoot: (defaults.object(forKey: "usageTargetBoot") as? NSNumber)?.int64Value,
      nowMillis: FilterCreditClock.nowMillis(), boot: boot, state: state, configuration: configuration)
  }

  static func allowsUnknownBrowser(bundleIdentifier: String, userID: UInt32?,
                                   configuration: [String: Any]?) -> Bool {
    guard let userID, let boot = FilterCreditClock.boot(),
          let snapshot = MacPolicyBrokerClient.shared.snapshot(for: userID,
            nowMillis: FilterCreditClock.nowMillis(), boot: boot) else { return false }
    return snapshot.allowsUnknownBrowserUsage(bundleIdentifier: bundleIdentifier,
      nowMillis: FilterCreditClock.nowMillis(), boot: boot, configuration: configuration)
  }
}
