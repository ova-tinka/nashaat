import Foundation

@main struct MacWebsiteUsageAccessCheck {
  static func main() {
    let configuration: [String: Any] = ["blockedDomains": ["example.com"]]
    let state = MacUsageState(sessionId: "session", userId: "user", budgetMillis: 1000,
      expiryElapsedMillis: 10_000, boot: 7, startedElapsedMillis: 100, usedMillis: 100, serverVerified: true)
    precondition(MacWebsiteUsageAccess.allows(host: "example.com", activeHost: "www.example.com",
      targetHeartbeatMillis: 500, targetBoot: 7, nowMillis: 500, boot: 7, state: state, configuration: configuration))
    precondition(!MacWebsiteUsageAccess.allows(host: "example.com", activeHost: "www.example.com",
      targetHeartbeatMillis: 500, targetBoot: 7, nowMillis: 1200, boot: 7, state: state, configuration: configuration))
    precondition(!MacWebsiteUsageAccess.allows(host: "example.com", activeHost: "www.example.com",
      targetHeartbeatMillis: 0, targetBoot: 7, nowMillis: 5001, boot: 7, state: state, configuration: configuration))
    precondition(!MacWebsiteUsageAccess.allows(host: "example.com", activeHost: "www.example.com",
      targetHeartbeatMillis: 500, targetBoot: 8, nowMillis: 500, boot: 7, state: state, configuration: configuration))
    precondition(!MacWebsiteUsageAccess.allows(host: "other.test", activeHost: "www.example.com",
      targetHeartbeatMillis: 500, targetBoot: 7, nowMillis: 500, boot: 7, state: state, configuration: configuration))
    precondition(!MacWebsiteUsageAccess.allows(host: "example.com", activeHost: nil,
      targetHeartbeatMillis: 500, targetBoot: 7, nowMillis: 500, boot: 7, state: state, configuration: configuration))
    precondition(MacWebsiteUsageAccess.allowsUnknownBrowser(bundleIdentifier: "com.google.Chrome",
      activeBrowserIdentifier: "com.google.Chrome", targetHeartbeatMillis: 500, targetBoot: 7,
      nowMillis: 500, boot: 7, state: state, configuration: configuration))
    precondition(!MacWebsiteUsageAccess.allowsUnknownBrowser(bundleIdentifier: "com.google.Chrome",
      activeBrowserIdentifier: "com.apple.Safari", targetHeartbeatMillis: 500, targetBoot: 7,
      nowMillis: 500, boot: 7, state: state, configuration: configuration))
    precondition(!MacWebsiteUsageAccess.allowsUnknownBrowser(bundleIdentifier: "com.google.Chrome",
      activeBrowserIdentifier: "com.google.Chrome", targetHeartbeatMillis: 0, targetBoot: 7,
      nowMillis: 5001, boot: 7, state: state, configuration: configuration))
    print("macOS website usage checks passed")
  }
}
