import Foundation
import SafariServices

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
  func beginRequest(with context: NSExtensionContext) {
    let item = context.inputItems.first as? NSExtensionItem
    let message = item?.userInfo?[SFExtensionMessageKey] as? [String: Any]
    let type = message?["type"] as? String ?? ""

    let replyPayload: [String: Any]
    switch type {
    case "getPolicy":
      replyPayload = readPolicy()
    case "openBloom":
      openBloomApp()
      replyPayload = ["ok": true, "type": "opened"]
    default:
      replyPayload = ["ok": false, "error": "Unsupported request."]
    }

    let response = NSExtensionItem()
    response.userInfo = [SFExtensionMessageKey: replyPayload]
    context.completeRequest(returningItems: [response], completionHandler: nil)
  }

  private func readPolicy() -> [String: Any] {
    guard let group = BloomAppGroup.identifier,
          FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
          let defaults = UserDefaults(suiteName: group) else {
      return ["ok": false, "error": "Bloom preferences are unavailable."]
    }

    let nowMillis = Date().timeIntervalSince1970 * 1000
    var heartbeats = (defaults.dictionary(forKey: "browserExtensionHeartbeats") as? [String: Double]) ?? [:]
    let lastWritten = heartbeats["safari"] ?? 0
    if nowMillis < lastWritten || (nowMillis - lastWritten) >= 10_000 {
      heartbeats["safari"] = nowMillis
      defaults.set(heartbeats, forKey: "browserExtensionHeartbeats")
    }

    let enabled = defaults.bool(forKey: "websiteBlockingEnabled")
    let blocked = (defaults.stringArray(forKey: "blockedDomains") ?? []).compactMap(WebsiteRules.host)
    let managed = (defaults.stringArray(forKey: "managedDomains") ?? []).compactMap(WebsiteRules.host)
    let now = FilterCreditClock.nowMillis()
    let boot = FilterCreditClock.boot()

    let creditConfig: [String: Any] = [
      "creditBoot": defaults.object(forKey: "creditBoot") ?? NSNull(),
      "creditDeadlineMillis": defaults.object(forKey: "creditDeadlineMillis") ?? NSNull(),
    ]
    let creditAllowed = FilterCreditClock.isAllowed(configuration: creditConfig)
    let creditRemaining = creditAllowed
      ? max(0, ((creditConfig["creditDeadlineMillis"] as? NSNumber)?.doubleValue ?? 0) - now)
      : 0

    let usageState = try? MacUsageStore.shared(group: group).read()
    let usageAllowed = usageState?.allows(now: now, boot: boot) == true
    let usageRemaining: Double = {
      guard usageAllowed, let state = usageState, let started = state.startedElapsedMillis else { return 0 }
      let deadline = min(state.expiryElapsedMillis, started + Double(state.budgetMillis))
      return max(0, deadline - now)
    }()

    let displayBalance = MacDisplayBalance.read(from: defaults)
    var payload: [String: Any] = [
      "ok": true,
      "type": "policy",
      "enabled": enabled,
      "blockedDomains": Array(Set(blocked)).sorted(),
      "managedDomains": Array(Set(managed)).sorted(),
      "accessAllowed": creditAllowed || usageAllowed,
      "remainingMillis": max(creditRemaining, usageRemaining),
      "creditsEnabled": displayBalance.creditsEnabled,
    ]
    if let minutes = displayBalance.balanceMinutes {
      payload["creditBalanceMinutes"] = minutes
    }
    return payload
  }

  private func openBloomApp() {
    let deepLink = Process()
    deepLink.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    deepLink.arguments = ["bloomexercise://focus?section=earned"]
    try? deepLink.run()
  }
}
