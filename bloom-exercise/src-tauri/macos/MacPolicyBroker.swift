import Foundation

/// Minimal, in-memory policy state passed from the logged-in monitor to the
/// root Network Extension. Browser URLs and page contents are never included.
struct MacPolicyBrokerSnapshot: Codable, Equatable {
  let userID: UInt32
  let publishedAtMillis: Double
  let websiteBlockingEnabled: Bool
  let browserAddressStatus: String
  let unreadableBrowserBundleIdentifier: String
  let activeBlockedBrowserBundleIdentifier: String
  let activeBlockedBrowserCheckedAtMillis: Double
  let activeBlockedBrowserBoot: Int64
  let monitorHeartbeatMillis: Double
  let monitorBoot: Int64
  let usageTargetDomain: String
  let usageTargetBrowser: String
  let usageTargetHeartbeatMillis: Double
  let usageTargetBoot: Int64
  let usageAccessDeadlineMillis: Double

  static let maximumEncodedSize = 4096
  static let browserStatusValues: Set<String> = ["readable", "unreadable", "unsupported", "inactive", "missing"]
  static let maximumHeartbeatAgeMillis = 15_000.0
  static let maximumUsageHeartbeatAgeMillis = 5_000.0
  static let maximumActiveBrowserAgeMillis = 2_500.0

  func isValid(for userID: UInt32, nowMillis: Double) -> Bool {
    self.userID == userID
      && userID > 0
      && publishedAtMillis.isFinite
      && nowMillis.isFinite
      && nowMillis >= publishedAtMillis
      && nowMillis - publishedAtMillis <= Self.maximumHeartbeatAgeMillis
      && Self.browserStatusValues.contains(browserAddressStatus)
      && unreadableBrowserBundleIdentifier.utf8.count <= 256
      && activeBlockedBrowserBundleIdentifier.utf8.count <= 256
      && usageTargetBrowser.utf8.count <= 256
      && usageTargetDomain.utf8.count <= 253
      && activeBlockedBrowserCheckedAtMillis.isFinite
      && activeBlockedBrowserBoot > 0
      && monitorHeartbeatMillis.isFinite
      && usageTargetHeartbeatMillis.isFinite
      && usageAccessDeadlineMillis.isFinite
  }

  func freshMonitor(nowMillis: Double, boot: Int64?) -> Bool {
    guard let boot, boot > 0, monitorBoot == boot,
          nowMillis.isFinite, monitorHeartbeatMillis.isFinite,
          nowMillis >= monitorHeartbeatMillis else { return false }
    return nowMillis - monitorHeartbeatMillis <= Self.maximumHeartbeatAgeMillis
  }

  func unreadableBrowserIdentifier(nowMillis: Double, boot: Int64?) -> String? {
    guard websiteBlockingEnabled, browserAddressStatus == "unreadable",
          !unreadableBrowserBundleIdentifier.isEmpty,
          freshMonitor(nowMillis: nowMillis, boot: boot) else { return nil }
    return unreadableBrowserBundleIdentifier
  }

  func shouldDropHostlessFlow(sourceBundleIdentifier: String?, nowMillis: Double, boot: Int64?) -> Bool {
    guard websiteBlockingEnabled, !activeBlockedBrowserBundleIdentifier.isEmpty,
          let boot, boot > 0, activeBlockedBrowserBoot == boot,
          MacFlowSource.matchesBrowserProcess(sourceBundleIdentifier: sourceBundleIdentifier,
            browserBundleIdentifier: activeBlockedBrowserBundleIdentifier),
          activeBlockedBrowserCheckedAtMillis.isFinite,
          nowMillis.isFinite, nowMillis >= activeBlockedBrowserCheckedAtMillis,
          nowMillis - activeBlockedBrowserCheckedAtMillis <= Self.maximumActiveBrowserAgeMillis,
          freshMonitor(nowMillis: nowMillis, boot: boot) else { return false }
    return true
  }

  func allowsWebsiteUsage(host: String, browserIdentifier: String?, nowMillis: Double,
                          boot: Int64?, configuration: [String: Any]?) -> Bool {
    let rules = WebsiteRules(configuration: configuration)
    guard websiteBlockingEnabled, rules.blocks(host),
          usageTargetDomain == host || (!usageTargetDomain.isEmpty && rules.blocks(usageTargetDomain)),
          nowMillis.isFinite, usageTargetHeartbeatMillis.isFinite,
          nowMillis >= usageTargetHeartbeatMillis,
          nowMillis - usageTargetHeartbeatMillis <= Self.maximumUsageHeartbeatAgeMillis,
          let boot, boot > 0, usageTargetBoot == boot,
          usageAccessDeadlineMillis.isFinite, nowMillis < usageAccessDeadlineMillis else { return false }

    if !usageTargetBrowser.isEmpty {
      return browserIdentifier == usageTargetBrowser
    }
    return true
  }

  func allowsUnknownBrowserUsage(bundleIdentifier: String, nowMillis: Double, boot: Int64?,
                                 configuration: [String: Any]?) -> Bool {
    guard websiteBlockingEnabled,
          !WebsiteRules(configuration: configuration).isEmpty,
          usageTargetBrowser == bundleIdentifier,
          nowMillis.isFinite, usageTargetHeartbeatMillis.isFinite,
          nowMillis >= usageTargetHeartbeatMillis,
          nowMillis - usageTargetHeartbeatMillis <= Self.maximumUsageHeartbeatAgeMillis,
          let boot, boot > 0, usageTargetBoot == boot,
          usageAccessDeadlineMillis.isFinite, nowMillis < usageAccessDeadlineMillis else { return false }
    return true
  }
}

/// A recent policy snapshot may be reused briefly when the privileged broker
/// misses an XPC request. Keep this fallback limited to foreground enforcement;
/// credit/usage grants still require a live broker snapshot.
enum MacPolicyBrokerCachePolicy {
  static func canReuseForForegroundEnforcement(snapshot: MacPolicyBrokerSnapshot,
                                                userID: UInt32,
                                                fetchedAtMillis: Double,
                                                nowMillis: Double,
                                                boot: Int64?) -> Bool {
    guard let boot, boot > 0,
          fetchedAtMillis.isFinite, nowMillis.isFinite,
          nowMillis >= fetchedAtMillis,
          nowMillis - fetchedAtMillis <= MacPolicyBrokerSnapshot.maximumActiveBrowserAgeMillis,
          snapshot.websiteBlockingEnabled,
          snapshot.isValid(for: userID, nowMillis: nowMillis),
          snapshot.freshMonitor(nowMillis: nowMillis, boot: boot) else { return false }
    return true
  }
}

enum MacPolicyBrokerAccessPolicy {
  static let hostIdentifier = "com.focusflow.focusFlowFlutter"
  static let monitorIdentifier = "com.focusflow.focusFlowFlutter.monitor"
  static let filterIdentifier = "com.focusflow.focusFlowFlutter.filter"

  static func mayConnect(peerIdentifier: String?, peerTeam: String?, expectedTeam: String) -> Bool {
    guard peerTeam == expectedTeam else { return false }
    return peerIdentifier == monitorIdentifier || peerIdentifier == filterIdentifier || peerIdentifier == hostIdentifier
  }

  static func connectionRequirement(peerIdentifier: String, expectedTeam: String) -> String? {
    guard [hostIdentifier, monitorIdentifier, filterIdentifier].contains(peerIdentifier),
          expectedTeam.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil else { return nil }
    return "identifier \"\(peerIdentifier)\" and anchor apple generic and certificate leaf[subject.OU] = \"\(expectedTeam)\""
  }

  static func mayPublish(peerIdentifier: String?, peerUID: UInt32, claimedUID: UInt32,
                         snapshotUID: UInt32) -> Bool {
    peerIdentifier == monitorIdentifier
      && peerUID > 0
      && claimedUID == peerUID
      && snapshotUID == peerUID
  }

  static func mayRead(peerIdentifier: String?, peerUID: UInt32) -> Bool {
    peerIdentifier == filterIdentifier && peerUID == 0
  }

  static func mayRequestHostsCleanup(peerIdentifier: String?, peerUID: UInt32) -> Bool {
    peerIdentifier == hostIdentifier && peerUID > 0
  }
}

struct MacProviderHeartbeat {
  let atMillis: Double
  let boot: Int64
  func isFresh(nowMillis: Double, boot: Int64?) -> Bool {
    guard let boot, boot > 0, self.boot == boot, atMillis.isFinite,
          nowMillis.isFinite, nowMillis >= atMillis else { return false }
    return nowMillis - atMillis <= 15_000
  }
}

final class MacPolicyBrokerStore {
  private let lock = NSLock()
  private var snapshots: [UInt32: MacPolicyBrokerSnapshot] = [:]
  private var provider: MacProviderHeartbeat?

  func recordProviderHeartbeat(peerIdentifier: String?, peerUID: UInt32, nowMillis: Double, boot: Int64?) -> Bool {
    guard MacPolicyBrokerAccessPolicy.mayRead(peerIdentifier: peerIdentifier, peerUID: peerUID),
          let boot, boot > 0, nowMillis.isFinite, nowMillis >= 0 else { return false }
    lock.lock(); defer { lock.unlock() }
    provider = MacProviderHeartbeat(atMillis: nowMillis, boot: boot)
    return true
  }

  func providerHeartbeat(peerIdentifier: String?, peerUID: UInt32, nowMillis: Double, boot: Int64?) -> MacProviderHeartbeat? {
    guard peerIdentifier == MacPolicyBrokerAccessPolicy.monitorIdentifier, peerUID > 0 else { return nil }
    lock.lock(); defer { lock.unlock() }
    guard let provider, provider.isFresh(nowMillis: nowMillis, boot: boot) else { return nil }
    return provider
  }

  func publish(_ data: Data, peerIdentifier: String?, peerUID: UInt32, claimedUID: UInt32,
               nowMillis: Double) -> Bool {
    guard data.count <= MacPolicyBrokerSnapshot.maximumEncodedSize,
          let snapshot = try? JSONDecoder().decode(MacPolicyBrokerSnapshot.self, from: data),
          MacPolicyBrokerAccessPolicy.mayPublish(peerIdentifier: peerIdentifier, peerUID: peerUID,
            claimedUID: claimedUID, snapshotUID: snapshot.userID),
          snapshot.isValid(for: peerUID, nowMillis: nowMillis) else { return false }
    lock.lock(); defer { lock.unlock() }
    snapshots[peerUID] = snapshot
    return true
  }

  func snapshot(for requestedUID: UInt32, peerIdentifier: String?, peerUID: UInt32,
                nowMillis: Double) -> Data? {
    guard MacPolicyBrokerAccessPolicy.mayRead(peerIdentifier: peerIdentifier, peerUID: peerUID),
          requestedUID > 0 else { return nil }
    lock.lock(); defer { lock.unlock() }
    guard let snapshot = snapshots[requestedUID], snapshot.isValid(for: requestedUID, nowMillis: nowMillis) else {
      snapshots.removeValue(forKey: requestedUID)
      return nil
    }
    return try? JSONEncoder().encode(snapshot)
  }
}

@objc protocol MacPolicyBrokerXPCProtocol {
  func publishSnapshot(_ data: Data, claimedUID: UInt32, reply: @escaping (Bool) -> Void)
  func snapshot(forUID uid: UInt32, reply: @escaping (Data?) -> Void)
  func reportProviderHeartbeat(reply: @escaping (Bool) -> Void)
  func providerHeartbeat(reply: @escaping (Double, Int64) -> Void)
  func cleanupHosts(_ authorization: Data, reply: @escaping (String) -> Void)
  func updateHosts(_ authorization: Data, domains: Data, reply: @escaping (String) -> Void)
  func startHostsUsage(_ request: Data, reply: @escaping (String) -> Void)
  func stopHostsUsage(_ profileID: String, sessionID: String, reply: @escaping (String) -> Void)
  func syncHostsManaged(_ profileID: String, accessToken: String, reply: @escaping (String) -> Void)
  func enrollHosts(_ authorization: Data, domains: Data, profileID: String, accessToken: String, reply: @escaping (String) -> Void)
  func hostsRecoveryStatus(reply: @escaping (String) -> Void)
  func hostsPolicyStatus(_ profileID: String, reply: @escaping (String) -> Void)
}
