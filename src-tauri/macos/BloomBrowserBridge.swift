import Darwin
import Foundation

enum MacNativeMessaging {
  static let maxMessageBytes = 65_536

  static func encodeMessage(_ payload: Data) -> Data? {
    guard payload.count <= maxMessageBytes else { return nil }
    var length = UInt32(payload.count).littleEndian
    var framed = Data(bytes: &length, count: 4)
    framed.append(payload)
    return framed
  }

  static func readMessage(from handle: FileHandle) -> Data? {
    guard let header = try? handle.read(upToCount: 4), header.count == 4 else { return nil }
    let length = header.withUnsafeBytes { pointer -> UInt32 in
      pointer.load(as: UInt32.self).littleEndian
    }
    guard length > 0, Int(length) <= maxMessageBytes else { return nil }
    guard let body = try? handle.read(upToCount: Int(length)), body.count == Int(length) else { return nil }
    return body
  }
}

enum MacBrowserHeartbeat {
  static let freshWindowMillis: Double = 120_000
  static let writeThrottleMillis: Double = 10_000

  static func classifyBrowser(executablePath: String) -> String? {
    let lower = executablePath.lowercased()
    if lower.contains("brave browser") || lower.contains("/brave") { return "brave" }
    if lower.contains("google chrome") { return "chrome" }
    if lower.contains("microsoft edge") { return "edge" }
    if lower.contains("/arc.app/") { return "arc" }
    return nil
  }

  static func shouldWrite(lastWrittenMillis: Double?, nowMillis: Double) -> Bool {
    guard let lastWrittenMillis, lastWrittenMillis.isFinite, nowMillis >= lastWrittenMillis else {
      return true
    }
    return nowMillis - lastWrittenMillis >= writeThrottleMillis
  }
}

#if BLOOM_BROWSER_BRIDGE
@_silgen_name("proc_pidpath")
private func bloom_proc_pidpath(_ pid: pid_t, _ buffer: UnsafeMutableRawPointer?, _ buffersize: UInt32) -> Int32

private struct BridgeRequest: Decodable {
  let type: String
}

private struct BridgePolicyResponse: Encodable {
  let ok: Bool
  let type: String
  let enabled: Bool
  let blockedDomains: [String]
  let managedDomains: [String]
  let accessAllowed: Bool
  let remainingMillis: Double
  let creditsEnabled: Bool
  let creditBalanceMinutes: Double?
}

private struct BridgeSimpleResponse: Encodable {
  let ok: Bool
  let type: String?
  let error: String?
}

@main struct BloomBrowserBridge {
  private static var lastHeartbeatWriteMillis: [String: Double] = [:]

  static func main() {
    let input = FileHandle.standardInput
    let output = FileHandle.standardOutput
    while let message = MacNativeMessaging.readMessage(from: input) {
      let reply = handle(message)
      if let framed = MacNativeMessaging.encodeMessage(reply) {
        output.write(framed)
      }
    }
  }

  private static func handle(_ data: Data) -> Data {
    guard let request = try? JSONDecoder().decode(BridgeRequest.self, from: data) else {
      return encodeSimple(ok: false, type: nil, error: "Invalid request.")
    }
    switch request.type {
    case "getPolicy":
      return readPolicy()
    case "openBloom":
      openBloomApp()
      return encodeSimple(ok: true, type: "opened", error: nil)
    default:
      return encodeSimple(ok: false, type: nil, error: "Unsupported request.")
    }
  }

  private static func recordParentHeartbeat(in defaults: UserDefaults) {
    var buffer = [CChar](repeating: 0, count: 4096)
    let length = bloom_proc_pidpath(getppid(), &buffer, UInt32(buffer.count))
    guard length > 0 else { return }
    let parentPath = String(cString: buffer)
    guard let browserId = MacBrowserHeartbeat.classifyBrowser(executablePath: parentPath) else { return }

    let nowMillis = Date().timeIntervalSince1970 * 1000
    guard MacBrowserHeartbeat.shouldWrite(lastWrittenMillis: lastHeartbeatWriteMillis[browserId], nowMillis: nowMillis) else {
      return
    }
    lastHeartbeatWriteMillis[browserId] = nowMillis
    var heartbeats = (defaults.dictionary(forKey: "browserExtensionHeartbeats") as? [String: Double]) ?? [:]
    heartbeats[browserId] = nowMillis
    defaults.set(heartbeats, forKey: "browserExtensionHeartbeats")
  }

  private static func readPolicy() -> Data {
    guard let group = BloomAppGroup.identifier,
          FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
          let defaults = UserDefaults(suiteName: group) else {
      return encodeSimple(ok: false, type: nil, error: "Bloom preferences are unavailable.")
    }
    recordParentHeartbeat(in: defaults)
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
    let response = BridgePolicyResponse(
      ok: true,
      type: "policy",
      enabled: enabled,
      blockedDomains: Array(Set(blocked)).sorted(),
      managedDomains: Array(Set(managed)).sorted(),
      accessAllowed: creditAllowed || usageAllowed,
      remainingMillis: max(creditRemaining, usageRemaining),
      creditsEnabled: displayBalance.creditsEnabled,
      creditBalanceMinutes: displayBalance.balanceMinutes
    )
    return (try? JSONEncoder().encode(response)) ?? encodeSimple(ok: false, type: nil, error: "Encoding failed.")
  }

  private static func openBloomApp() {
    let deepLink = Process()
    deepLink.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    deepLink.arguments = ["bloomexercise://focus?section=earned"]
    if (try? deepLink.run()) != nil {
      deepLink.waitUntilExit()
      if deepLink.terminationStatus == 0 {
        return
      }
    }

    var appPath = "/Applications/Bloom.app"
    if let arg0 = CommandLine.arguments.first {
      let candidate = URL(fileURLWithPath: arg0)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
      if candidate.pathExtension == "app" {
        appPath = candidate.path
      }
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", appPath]
    try? process.run()
  }

  private static func encodeSimple(ok: Bool, type: String?, error: String?) -> Data {
    (try? JSONEncoder().encode(BridgeSimpleResponse(ok: ok, type: type, error: error)))
      ?? Data("{\"ok\":false}".utf8)
  }
}
#endif
