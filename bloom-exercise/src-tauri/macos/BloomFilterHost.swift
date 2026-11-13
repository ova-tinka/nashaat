import Foundation

private struct FilterRequest: Decodable {
  let action: String
  let domains: [String]?
  let apps: [String]?
  let creditRequestId: String?
  let creditDeviceKey: String?
  let creditMinutes: Double?
  let creditAccessToken: String?
  let usageRequestId: String?
  let usageDeviceKey: String?
  let usageRequestedMillis: Int64?
  let usageAccessToken: String?
  let hostsGrantKind: String?
  let creditWebsites: Bool?
  let creditApps: Bool?
  let accountId: String?
  let sessionId: String?
  let userId: String?
}

private struct FilterResponse: Encodable {
  let ok: Bool
  var status: String?
  var domains: [String]?
  var apps: [String]?
  var appEnabled: Bool?
  var appConfigured: Bool?
  var appService: String?
  var websiteUsageAvailable: Bool?
  var websiteProviderHealthy: Bool?
  var websitePolicyBrokerStatus: String?
  var accessibilityTrusted: Bool?
  var browserName: String?
  var browserAddressStatus: String?
  var browserAutomationStatus: String?
  var supportedBrowsers: [String]?
  var browserHideFailed: Bool?
  var appHideFailed: Bool?
  var managedApps: [String]?
  var managedDomains: [String]?
  var managedRuleAccountId: String?
  var selectedAppId: String?
  var selectedAppName: String?
  var installedApps: MacInstalledApps?
  var elapsedMillis: Double?
  var boot: Int64?
  var remainingMillis: Double?
  var usage: UsageResponse?
  var error: String?
}

private struct UsageResponse: Encodable {
  let sessionId: String
  let userId: String
  let budgetMillis: Int64
  let usedMillis: Int64
  let remainingMillis: Int64
  let closed: Bool
  let tracking: Bool
  let verified: Bool

  init(_ state: MacUsageState) {
    sessionId = state.sessionId; userId = state.userId; budgetMillis = state.budgetMillis
    usedMillis = state.usedMillis; remainingMillis = max(0, state.budgetMillis - state.usedMillis)
    closed = state.closed; tracking = state.activeSinceMillis != nil; verified = state.serverVerified == true
  }
}

/// A local helper bridge. Requests arrive over stdin to keep selected domains
/// out of the process command line; this helper never sends them elsewhere.
struct BloomFilterHost {
  @MainActor static func handle(_ input: Data) async -> Data {
    let response: FilterResponse
    do {
      guard input.count <= 100_000 else { throw HostError.invalidRequest }
      let request = try JSONDecoder().decode(FilterRequest.self, from: input)
      let gated = ["start", "stop", "clearManualDomains", "cleanupHosts", "enrollHosts", "startHostsUsage", "stopHostsUsage",
        "syncManagedRules", "startUsageAccess", "closeUsageAccess", "clearUsageAccess", "startCreditAccess", "endCreditAccess"].contains(request.action)
      if gated { try MacHostsLifecycleGate.shared.acquire() }
      defer { if gated { MacHostsLifecycleGate.shared.release() } }
      switch request.action {
      case "inspectBundle":
        response = FilterResponse(ok: true, status: Bundle.main.bundleIdentifier ?? "unbundled",
          appService: Bundle.main.object(forInfoDictionaryKey: "BloomAppGroup") == nil ? "missingGroup" : "groupConfigured")
      case "activate":
        let value = try await BloomFilterController.shared.activate()
        response = FilterResponse(ok: true, status: value.rawValue)
      case "start":
        if let usage = try? BloomAppController.shared.usageStatus(), !usage.closed { throw HostError.usageActive }
        let domains = request.domains ?? []
        guard !domains.isEmpty, domains.count <= 500, domains.allSatisfy({ WebsiteRules.host($0) != nil }) else {
          throw HostError.invalidRequest
        }
        switch try await BloomFilterController.shared.activate() {
        case .active:
          try await BloomFilterController.shared.start(domains: domains)
          response = FilterResponse(ok: true, status: "enabled")
        case .needsApproval:
          response = FilterResponse(ok: true, status: "needsApproval")
        case .needsBrokerApproval:
          response = FilterResponse(ok: true, status: "needsBrokerApproval")
        case .needsRestart:
          response = FilterResponse(ok: true, status: "needsRestart")
        }
      case "stop":
        if let usage = try? BloomAppController.shared.usageStatus(), !usage.closed { throw HostError.usageActive }
        try await BloomFilterController.shared.stop()
        response = FilterResponse(ok: true, status: "disabled")
      case "clearManualDomains":
        try await BloomFilterController.shared.clearManualDomains()
        response = FilterResponse(ok: true, status: "cleared")
      case "cleanupHosts":
        let service = try BloomPolicyBrokerController.shared.ensureRegistered()
        guard service == "active" else { throw HostError.hostsServiceUnavailable }
        let grant: MacHostsAdminGrant
        do { grant = try MacHostsAdminGrant.request() } catch { throw HostError.hostsDenied }
        let external = try grant.externalForm()
        let result = await withCheckedContinuation { continuation in
          MacPolicyBrokerClient.shared.cleanupHosts(authorization: external) { continuation.resume(returning: $0) }
        }
        withExtendedLifetime(grant) {}
        switch result {
        case "cleaned":
          guard MacSharedPreferences.write(removing: ["hostsFallbackExpected"]) else { throw HostError.hostsUncertain }
          response = FilterResponse(ok: true, status: "cleaned")
        case "conflict": throw HostError.hostsConflict
        case "denied": throw HostError.hostsDenied
        case "uncertain": throw HostError.hostsUncertain
        case "unsafe": throw HostError.hostsUnsafe
        case "busy": throw HostError.hostsBusy
        case "recoveryRequired": throw HostError.hostsRecoveryRequired
        default: throw HostError.hostsServiceUnavailable
        }
      case "enrollHosts":
        guard let profile = request.userId, UUID(uuidString: profile) != nil,
              let token = request.usageAccessToken, !token.isEmpty, token.utf8.count <= 8192 else { throw HostError.invalidRequest }
        let website = try await BloomFilterController.shared.status()
        guard website.enabled, !website.domains.isEmpty else { throw HostError.invalidRequest }
        guard website.remainingMillis <= 0, try BloomAppController.shared.status().remainingMillis <= 0 else { throw HostError.usageActive }
        if let usage = try BloomAppController.shared.usageStatus(), !usage.closed { throw HostError.usageActive }
        let manual = try BloomFilterController.shared.manualDomains()
        guard try BloomPolicyBrokerController.shared.ensureRegistered() == "active" else { throw HostError.hostsServiceUnavailable }
        let grant: MacHostsAdminGrant
        do { grant = try MacHostsAdminGrant.request() } catch { throw HostError.hostsDenied }
        let authorization = try grant.externalForm()
        let encoded = try JSONEncoder().encode(manual)
        // Record intent before sending: the broker may commit even if its
        // response is lost or the host terminates during the request.
        guard MacSharedPreferences.write(["hostsFallbackExpected": true]) else { throw HostError.hostsServiceUnavailable }
        let result = await withCheckedContinuation { continuation in
          MacPolicyBrokerClient.shared.enrollHosts(authorization: authorization, domains: encoded,
            profileID: profile, accessToken: token) { continuation.resume(returning: $0) }
        }
        withExtendedLifetime(grant) {}
        try requireHostsResult(result, allowed: ["updated"])
        response = FilterResponse(ok: true, status: "enrolled")
      case "startHostsUsage":
        guard let profile = request.userId, UUID(uuidString: profile) != nil,
              let key = request.usageDeviceKey, UUID(uuidString: key) != nil,
              let token = request.usageAccessToken, !token.isEmpty, token.utf8.count <= 8192,
              let kind = request.hostsGrantKind, kind == "easy" || kind == "countdown" else { throw HostError.invalidRequest }
        var payload = ["kind": kind, "profileID": profile, "deviceKey": key, "accessToken": token]
        if kind == "easy" {
          guard let usage = try BloomAppController.shared.usageStatus(),
                UUID(uuidString: usage.userId) == UUID(uuidString: profile),
                usage.allows(now: FilterCreditClock.nowMillis(), boot: FilterCreditClock.boot()) else { throw HostError.invalidRequest }
          payload["sessionID"] = usage.sessionId
        } else {
          guard let id = request.usageRequestId, UUID(uuidString: id) != nil else { throw HostError.invalidRequest }
          payload["requestID"] = id
        }
        guard BloomPolicyBrokerController.shared.status() == "active" else { throw HostError.hostsServiceUnavailable }
        if kind == "easy", let session = payload["sessionID"] {
          try await openEasyHosts(profileID: profile, sessionID: session, deviceKey: key, accessToken: token)
        } else {
          let encoded = try JSONEncoder().encode(payload)
          let result = await withCheckedContinuation { continuation in
            MacPolicyBrokerClient.shared.startHostsUsage(request: encoded) { continuation.resume(returning: $0) }
          }
          try requireHostsResult(result, allowed: ["updated"])
        }
        response = FilterResponse(ok: true, status: "allowed")
      case "stopHostsUsage":
        guard let profile = request.userId, UUID(uuidString: profile) != nil,
              let session = request.sessionId, UUID(uuidString: session) != nil else { throw HostError.invalidRequest }
        guard BloomPolicyBrokerController.shared.status() == "active" else { throw HostError.hostsServiceUnavailable }
        let result = await withCheckedContinuation { continuation in
          MacPolicyBrokerClient.shared.stopHostsUsage(profileID: profile, sessionID: session) { continuation.resume(returning: $0) }
        }
        try requireHostsResult(result, allowed: ["closed", "inactive"])
        response = FilterResponse(ok: true, status: result)
      case "syncHostsManaged":
        guard let profile = request.userId, UUID(uuidString: profile) != nil,
              let token = request.usageAccessToken, !token.isEmpty, token.utf8.count <= 8192 else { throw HostError.invalidRequest }
        guard BloomPolicyBrokerController.shared.status() == "active" else { throw HostError.hostsServiceUnavailable }
        let status = await withCheckedContinuation { continuation in
          MacPolicyBrokerClient.shared.syncHostsManaged(profileID: profile, accessToken: token) { continuation.resume(returning: $0) }
        }
        response = FilterResponse(ok: true, status: status)
      case "hostsPolicyStatus":
        guard let profile = request.userId, UUID(uuidString: profile) != nil else { throw HostError.invalidRequest }
        if BloomPolicyBrokerController.shared.status() != "active" {
          response = FilterResponse(ok: true, status: "unavailable")
        } else {
          let status = await withCheckedContinuation { continuation in
            MacPolicyBrokerClient.shared.hostsPolicyStatus(profileID: profile) { continuation.resume(returning: $0) }
          }
          response = FilterResponse(ok: true, status: status)
        }
      case "hostsRecoveryStatus":
        if BloomPolicyBrokerController.shared.status() != "active" {
          response = FilterResponse(ok: true, status: "unavailable")
        } else {
          let status = await withCheckedContinuation { continuation in
            MacPolicyBrokerClient.shared.hostsRecoveryStatus { continuation.resume(returning: $0) }
          }
          response = FilterResponse(ok: true, status: status)
        }
      case "status":
        let web = try await BloomFilterController.shared.status()
        response = FilterResponse(ok: true, status: web.enabled ? "enabled" : "disabled", domains: web.domains,
          managedDomains: BloomFilterController.shared.managedDomains(), remainingMillis: web.remainingMillis)
      case "appStatus":
        let app = try BloomAppController.shared.status()
        response = FilterResponse(ok: true, apps: app.apps, appEnabled: app.enabled, appConfigured: app.configured, appService: app.service,
          websiteUsageAvailable: app.websiteUsageAvailable, websiteProviderHealthy: app.websiteProviderHealthy, websitePolicyBrokerStatus: app.websitePolicyBrokerStatus,
          accessibilityTrusted: app.accessibilityTrusted,
          browserName: app.browserName, browserAddressStatus: app.browserAddressStatus,
          browserAutomationStatus: app.browserAutomationStatus, supportedBrowsers: MacBrowserURL.supportedNames,
          browserHideFailed: app.browserHideFailed,
          appHideFailed: app.appHideFailed,
          managedApps: BloomAppController.shared.managedApps(), managedRuleAccountId: app.managedRuleAccountId,
          remainingMillis: app.remainingMillis)
      case "openAccessibilitySettings":
        try BloomAppController.shared.openAccessibilitySettings()
        response = FilterResponse(ok: true, status: "opened")
      case "syncManagedRules":
        guard let accountId = request.accountId, !accountId.isEmpty else { throw HostError.invalidRequest }
        let managedApps = request.apps ?? []
        let managedDomains = request.domains ?? []
        let appStatus = try BloomAppController.shared.syncManagedApps(managedApps, accountId: accountId)
        let monitorStatus = (managedApps.isEmpty && managedDomains.isEmpty) ? "inactive" : try BloomAppController.shared.ensureMonitor()
        let websiteStatus = try await BloomFilterController.shared.syncManagedDomains(managedDomains, accountId: accountId)
        let statuses = [appStatus, monitorStatus, websiteStatus]
        let status = statuses.contains("needsApproval") ? "needsApproval"
          : statuses.contains("needsBrokerApproval") ? "needsBrokerApproval"
          : statuses.contains("needsRestart") ? "needsRestart"
          : statuses.contains("unavailable") ? "unavailable" : "synced"
        response = FilterResponse(ok: true, status: status)
      case "getUsageAccess":
        let usage = try BloomAppController.shared.usageStatus()
        response = FilterResponse(ok: true, usage: usage.map(UsageResponse.init))
      case "startUsageAccess":
        guard let user = request.userId, let requestId = request.usageRequestId, let deviceKey = request.usageDeviceKey,
              let requested = request.usageRequestedMillis, let token = request.usageAccessToken,
              let boot = FilterCreditClock.boot() else { throw HostError.invalidRequest }
        try BloomAppController.shared.validateUsageReady()
        let useHosts = try await hostsFallbackConfigured(profileID: user, starting: true)
        let elapsed = FilterCreditClock.nowMillis()
        let grant = try await SupabaseUsageGrant.reserve(requestId: requestId, deviceKey: deviceKey,
          requestedMillis: requested, profileId: user, accessToken: token)
        try BloomAppController.shared.startUsage(session: grant.sessionId, user: user, budget: grant.budgetMillis,
          expiry: Double(grant.remainingMillis), requestElapsed: elapsed, requestBoot: boot)
        if useHosts { try await openEasyHosts(profileID: user, sessionID: grant.sessionId, deviceKey: deviceKey, accessToken: token) }
        response = FilterResponse(ok: true, status: "allowed")
      case "closeUsageAccess":
        guard let user = request.userId else { throw HostError.invalidRequest }
        let closed = try BloomAppController.shared.closeUsage(user: user)
        if let closed, try await hostsFallbackConfigured(profileID: user, starting: false) {
          let result = await withCheckedContinuation { continuation in
            MacPolicyBrokerClient.shared.stopHostsUsage(profileID: user, sessionID: closed.sessionId) { continuation.resume(returning: $0) }
          }
          try requireHostsResult(result, allowed: ["closed", "inactive"])
        }
        response = FilterResponse(ok: true, usage: closed.map(UsageResponse.init))
      case "clearUsageAccess":
        guard let user = request.userId, let session = request.sessionId else { throw HostError.invalidRequest }
        try BloomAppController.shared.clearUsage(user: user, session: session)
        response = FilterResponse(ok: true, status: "cleared")
      case "activateApps":
        response = FilterResponse(ok: true, status: try BloomAppController.shared.activate())
      case "chooseApp":
        let selected = try BloomAppController.shared.chooseApp()
        response = FilterResponse(ok: true, status: selected == nil ? "cancelled" : "selected", selectedAppId: selected?.id, selectedAppName: selected?.name)
      case "listInstalledApps":
        let userApps = FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask).first
        let roots = [URL(fileURLWithPath: "/Applications", isDirectory: true),
          URL(fileURLWithPath: "/System/Applications", isDirectory: true)] + (userApps.map { [$0] } ?? [])
        let catalog = await Task.detached(priority: .userInitiated) { MacInstalledApps.scan(roots: roots) }.value
        response = FilterResponse(ok: true, installedApps: catalog)
      case "startApps":
        try BloomAppController.shared.start(apps: request.apps ?? [])
        response = FilterResponse(ok: true, status: "enabled")
      case "stopApps":
        try BloomAppController.shared.stop()
        response = FilterResponse(ok: true, status: "disabled")
      case "clearManualApps":
        try BloomAppController.shared.clearManualApps()
        response = FilterResponse(ok: true, status: "cleared")
      case "clock":
        guard let boot = FilterCreditClock.boot() else { throw HostError.clockUnavailable }
        response = FilterResponse(ok: true, elapsedMillis: FilterCreditClock.nowMillis(), boot: boot)
      case "startCreditAccess":
        guard let requestId = request.creditRequestId, let deviceKey = request.creditDeviceKey,
              let minutes = request.creditMinutes, let accessToken = request.creditAccessToken,
              let boot = FilterCreditClock.boot() else { throw HostError.invalidRequest }
        guard request.creditWebsites == true || request.creditApps == true else { throw HostError.invalidRequest }
        let profile: String?
        let useHosts: Bool
        if request.creditWebsites == true {
          guard let account = request.accountId, UUID(uuidString: account) != nil else { throw HostError.invalidRequest }
          profile = account
          useHosts = try await hostsFallbackConfigured(profileID: account, starting: true)
        } else {
          profile = nil
          useHosts = false
        }
        let requestElapsed = FilterCreditClock.nowMillis()
        do {
          let grant = try await SupabaseCreditGrant.start(requestId: requestId, deviceKey: deviceKey,
            minutes: minutes, accessToken: accessToken)
          guard let deadline = FilterCreditClock.deadline(duration: Double(grant.remainingMillis), requestElapsed: requestElapsed,
            now: FilterCreditClock.nowMillis(), requestBoot: boot, boot: FilterCreditClock.boot()) else { throw HostError.clockUnavailable }
          var hostsAttempted = false
          var websiteAttempted = false
          do {
            if useHosts, let profile {
              hostsAttempted = true
              try await openCountdownHosts(profileID: profile, requestID: requestId, deviceKey: deviceKey,
                sessionID: grant.sessionId, accessToken: accessToken)
            }
            if request.creditWebsites == true {
              websiteAttempted = true
              try await BloomFilterController.shared.startCreditAccess(deadlineMillis: deadline, boot: boot)
            }
            if request.creditApps == true { try BloomAppController.shared.setCredit(deadline: deadline, boot: boot) }
          } catch {
            if hostsAttempted, let profile { try await closeCountdownHosts(profileID: profile) }
            if websiteAttempted { try? await BloomFilterController.shared.endCreditAccess() }
            if request.creditApps == true { try? BloomAppController.shared.clearCredit() }
            throw error
          }
          response = FilterResponse(ok: true, status: "allowed")
        } catch SupabaseCreditGrantError.expired {
          if let profile { try await closeCountdownHosts(profileID: profile) }
          if request.creditWebsites == true { try? await BloomFilterController.shared.endCreditAccess() }
          if request.creditApps == true { try? BloomAppController.shared.clearCredit() }
          response = FilterResponse(ok: true, status: "expired")
        } catch SupabaseCreditGrantError.rejected {
          if let profile { try await closeCountdownHosts(profileID: profile) }
          if request.creditWebsites == true { try? await BloomFilterController.shared.endCreditAccess() }
          if request.creditApps == true { try? BloomAppController.shared.clearCredit() }
          response = FilterResponse(ok: true, status: "rejected")
        }
      case "endCreditAccess":
        if request.creditWebsites ?? true, let profile = request.accountId {
          try await closeCountdownHosts(profileID: profile)
        }
        if request.creditWebsites ?? true { try await BloomFilterController.shared.endCreditAccess() }
        if request.creditApps ?? true { try BloomAppController.shared.clearCredit() }
        response = FilterResponse(ok: true, status: "blocked")
      default:
        throw HostError.invalidRequest
      }
    } catch {
      response = FilterResponse(ok: false, error: error.localizedDescription)
    }
    return (try? JSONEncoder().encode(response)) ?? Data("{\"ok\":false,\"error\":\"Could not encode the response.\"}".utf8)
  }

  @MainActor private static func openEasyHosts(profileID: String, sessionID: String, deviceKey: String, accessToken: String) async throws {
    let payload = ["kind": "easy", "profileID": profileID, "sessionID": sessionID,
      "deviceKey": deviceKey, "accessToken": accessToken]
    let data = try JSONEncoder().encode(payload)
    let result = await withCheckedContinuation { continuation in
      MacPolicyBrokerClient.shared.startHostsUsage(request: data) { continuation.resume(returning: $0) }
    }
    try requireHostsResult(result, allowed: ["updated"])
    if let current = try? BloomAppController.shared.usageStatus(),
       UUID(uuidString: current.userId) == UUID(uuidString: profileID),
       UUID(uuidString: current.sessionId) == UUID(uuidString: sessionID),
       current.allows(now: FilterCreditClock.nowMillis(), boot: FilterCreditClock.boot()) { return }
    let stopped = await withCheckedContinuation { continuation in
      MacPolicyBrokerClient.shared.stopHostsUsage(profileID: profileID, sessionID: sessionID) { continuation.resume(returning: $0) }
    }
    try requireHostsResult(stopped, allowed: ["closed", "inactive"])
    throw HostError.hostsExpired
  }

  @MainActor private static func hostsFallbackConfigured(profileID: String, starting: Bool) async throws -> Bool {
    guard UUID(uuidString: profileID) != nil, let group = BloomAppGroup.identifier,
          FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
          let defaults = UserDefaults(suiteName: group) else { throw HostError.hostsServiceUnavailable }
    let expected = defaults.bool(forKey: "hostsFallbackExpected")
    let status: String
    if BloomPolicyBrokerController.shared.status() != "active" { status = "unavailable" }
    else {
      status = await withCheckedContinuation { continuation in
        MacPolicyBrokerClient.shared.hostsPolicyStatus(profileID: profileID) { continuation.resume(returning: $0) }
      }
    }
    if MacHostsFallbackDecision.shouldRemember(status: status), !expected,
       !MacSharedPreferences.write(["hostsFallbackExpected": true]) {
      throw HostError.hostsServiceUnavailable
    }
    switch MacHostsFallbackDecision.decide(status: status, expected: expected, starting: starting) {
    case .use: return true
    case .skip: return false
    case .otherAccount: throw HostError.hostsOtherAccount
    case .unavailable: throw HostError.hostsServiceUnavailable
    }
  }

  @MainActor private static func openCountdownHosts(profileID: String, requestID: String, deviceKey: String,
                                                      sessionID: String, accessToken: String) async throws {
    guard UUID(uuidString: profileID) != nil, UUID(uuidString: requestID) != nil,
          UUID(uuidString: deviceKey) != nil, UUID(uuidString: sessionID) != nil,
          BloomPolicyBrokerController.shared.status() == "active" else { throw HostError.hostsServiceUnavailable }
    // Persist a close handle before XPC: the broker can commit even when its
    // reply is lost or the app exits while the request is in flight.
    guard MacSharedPreferences.write(["hostsFallbackExpected": true,
      "hostsCreditProfileID": profileID, "hostsCreditSessionID": sessionID]) else { throw HostError.hostsServiceUnavailable }
    let payload = ["kind": "countdown", "profileID": profileID, "requestID": requestID,
      "deviceKey": deviceKey, "accessToken": accessToken]
    let encoded = try JSONEncoder().encode(payload)
    let result = await withCheckedContinuation { continuation in
      MacPolicyBrokerClient.shared.startHostsUsage(request: encoded) { continuation.resume(returning: $0) }
    }
    try requireHostsResult(result, allowed: ["updated"])
  }

  @MainActor private static func closeCountdownHosts(profileID: String) async throws {
    guard UUID(uuidString: profileID) != nil, let group = BloomAppGroup.identifier,
          FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
          let defaults = UserDefaults(suiteName: group) else { throw HostError.hostsServiceUnavailable }
    let storedProfile = defaults.string(forKey: "hostsCreditProfileID")
    let sessionID = defaults.string(forKey: "hostsCreditSessionID")
    guard storedProfile != nil || sessionID != nil else { return }
    guard let storedProfile, let sessionID, UUID(uuidString: storedProfile) != nil,
          UUID(uuidString: sessionID) != nil else { throw HostError.hostsUncertain }
    guard UUID(uuidString: storedProfile) == UUID(uuidString: profileID) else { throw HostError.hostsOtherAccount }
    guard BloomPolicyBrokerController.shared.status() == "active" else { throw HostError.hostsServiceUnavailable }
    let result = await withCheckedContinuation { continuation in
      MacPolicyBrokerClient.shared.stopHostsUsage(profileID: profileID, sessionID: sessionID) { continuation.resume(returning: $0) }
    }
    try requireHostsResult(result, allowed: ["closed", "inactive"])
    guard MacSharedPreferences.write(removing: ["hostsCreditProfileID", "hostsCreditSessionID"]) else {
      throw HostError.hostsUncertain
    }
  }

  private static func requireHostsResult(_ result: String, allowed: Set<String>) throws {
    guard !allowed.contains(result) else { return }
    switch result {
    case "conflict": throw HostError.hostsConflict
    case "denied": throw HostError.hostsDenied
    case "uncertain": throw HostError.hostsUncertain
    case "unsafe": throw HostError.hostsUnsafe
    case "busy": throw HostError.hostsBusy
    case "recoveryRequired": throw HostError.hostsRecoveryRequired
    case "stale": throw HostError.hostsStale
    case "expired": throw HostError.hostsExpired
    case "invalid": throw HostError.invalidRequest
    case "otherAccount": throw HostError.hostsOtherAccount
    case "needsEnrollment": throw HostError.hostsRecoveryRequired
    case "usageActive": throw HostError.usageActive
    default: throw HostError.hostsServiceUnavailable
    }
  }

  private enum HostError: LocalizedError {
    case invalidRequest, clockUnavailable, usageActive, hostsServiceUnavailable, hostsConflict, hostsDenied, hostsUncertain, hostsUnsafe, hostsBusy, hostsRecoveryRequired, hostsStale, hostsExpired, hostsOtherAccount
    var errorDescription: String? {
      switch self {
      case .invalidRequest: return "Invalid Bloom filter request."
      case .clockUnavailable: return "Could not verify this Mac’s uptime."
      case .usageActive: return "Finish the active screen-time session before changing website blocking."
      case .hostsServiceUnavailable: return "Bloom could not contact its approved hosts service. Check Background Items in System Settings."
      case .hostsConflict: return "Bloom could not safely update its hosts entries because the file changed or its Bloom block was altered."
      case .hostsDenied: return "Administrator authorization was not accepted."
      case .hostsUncertain: return "The hosts service did not confirm the result. Check recovery status before retrying."
      case .hostsUnsafe: return "Bloom could not safely update the hosts file because its permissions, links, ACL, or contents are unsupported. No cleanup was completed."
      case .hostsBusy: return "Another hosts update is in progress. Try again shortly."
      case .hostsOtherAccount: return "Hosts fallback belongs to another account on this Mac. Sign in to that account or ask an administrator to remove it."
      case .hostsStale: return "Website protection changed while this request was running. Refresh and try again."
      case .hostsExpired: return "The screen-time session has ended or can no longer be used on this Mac."
      case .hostsRecoveryRequired: return "A hosts update was interrupted or conflicted with another editor. An administrator must review the preserved file in /private/etc/.bloom-hosts before retrying."
      }
    }
  }
}

#if BLOOM_HELPER
@main struct BloomHelperMain {
  @MainActor static func main() async {
    let output = await BloomFilterHost.handle(FileHandle.standardInput.readDataToEndOfFile())
    FileHandle.standardOutput.write(output)
  }
}
#else
public typealias BloomResponseCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void

@_cdecl("bloom_filter_request")
public func bloomFilterRequest(_ request: UnsafePointer<CChar>?, _ context: UnsafeMutableRawPointer?, _ callback: @escaping BloomResponseCallback) {
  guard let request else { callback(context, nil); return }
  let input = Data(String(cString: request).utf8)
  Task { @MainActor in
    let output = await BloomFilterHost.handle(input)
    guard let response = String(data: output, encoding: .utf8) else { callback(context, nil); return }
    response.withCString { callback(context, $0) }
  }
}
#endif
