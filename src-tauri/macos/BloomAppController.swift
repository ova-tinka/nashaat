import Foundation
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

@MainActor final class BloomAppController {
  static let shared = BloomAppController()
  private let plist = "com.focusflow.focusFlowFlutter.monitor.plist"
  private let registrationFingerprintKey = "monitorRegisteredExecutableFingerprint"

  private var defaults: UserDefaults? {
    guard let group = BloomAppGroup.identifier,
          FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil else { return nil }
    return UserDefaults(suiteName: group)
  }

  func activate() throws -> String {
    try ensureMonitor()
  }

  func ensureMonitor() throws -> String {
    let service = SMAppService.agent(plistName: plist)
    let agentPlist = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchAgents/\(plist)")
    let agentExecutable = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/BloomAppMonitor")
    guard FileManager.default.isReadableFile(atPath: agentPlist.path),
          FileManager.default.isExecutableFile(atPath: agentExecutable.path) else {
      throw AppError.monitorNotFound
    }
    let fingerprint = try MacServiceRegistrationPolicy.fingerprint(at: agentExecutable)
    let wasRegistered = service.status == .enabled || service.status == .requiresApproval
    if MacServiceRegistrationPolicy.shouldRefresh(isRegistered: wasRegistered,
      registeredFingerprint: UserDefaults.standard.string(forKey: registrationFingerprintKey),
      currentFingerprint: fingerprint) {
      // A copied or updated Bloom app can leave Service Management pointing at
      // an older helper that is still alive. Refresh only when the executable
      // changed, then register from this signed app copy.
      try service.unregister()
    }
    if service.status == .enabled, let defaults, !isMonitorRunning(defaults) {
      // A previous app copy or a crashed helper can leave Service Management
      // enabled while its process no longer reports a heartbeat. Re-register
      // from the currently running app bundle so updates recover cleanly.
      try service.unregister()
    }
    if service.status == .notRegistered || service.status == .notFound {
      try service.register()
      // Service Management may return a transient .notFound immediately after
      // register() while it records the bundled launch agent. Give it a short
      // window to publish the resulting state before treating this as a broken
      // app bundle.
      for _ in 0..<20 {
        let status = service.status
        if status != .notFound && status != .notRegistered {
          UserDefaults.standard.set(fingerprint, forKey: registrationFingerprintKey)
          return try monitorStatus(status)
        }
        Thread.sleep(forTimeInterval: 0.1)
      }
    }
    if service.status == .enabled || service.status == .requiresApproval {
      UserDefaults.standard.set(fingerprint, forKey: registrationFingerprintKey)
    }
    return try monitorStatus(service.status)
  }

  func waitForWebsitePolicyReady(timeoutMillis: Double = 5_000) async -> Bool {
    guard let defaults else { return false }
    let deadline = FilterCreditClock.nowMillis() + timeoutMillis
    while FilterCreditClock.nowMillis() <= deadline {
      let brokerStatus = BloomPolicyBrokerController.shared.status()
      let acknowledgement = (defaults.object(forKey: "monitorPolicyBrokerSnapshotAckMillis") as? NSNumber)?.doubleValue
      if BloomPolicyBrokerReadiness.isReady(serviceStatus: brokerStatus,
        monitorRunning: isMonitorRunning(defaults),
        snapshotAccepted: defaults.bool(forKey: "monitorPolicyBrokerSnapshotAccepted"),
        acknowledgementMillis: acknowledgement,
        nowMillis: FilterCreditClock.nowMillis()) {
        return true
      }
      do {
        try await Task.sleep(nanoseconds: 100_000_000)
      } catch {
        return false
      }
    }
    return false
  }

  private func monitorStatus(_ status: SMAppService.Status) throws -> String {
    switch status {
    case .enabled: return "active"
    case .requiresApproval: return "needsApproval"
    case .notRegistered: throw AppError.monitorNotRegistered
    case .notFound: throw AppError.monitorNotFound
    @unknown default: throw AppError.unavailable
    }
  }

  func openAccessibilitySettings() throws {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"),
          NSWorkspace.shared.open(url) else { throw AppError.unavailable }
  }

  func chooseApp() throws -> (id: String, name: String)? {
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    application.activate(ignoringOtherApps: true)
    let panel = NSOpenPanel()
    panel.title = "Choose an app to block"
    panel.allowedContentTypes = [.applicationBundle]
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier,
          let normalized = MacAppRules.normalize([identifier])?.first else { throw AppError.invalidApps }
    return (normalized, (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
      ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? url.deletingPathExtension().lastPathComponent)
  }

  func status() throws -> (enabled: Bool, configured: Bool, apps: [String], service: String, remainingMillis: Double,
                           websiteUsageAvailable: Bool, accessibilityTrusted: Bool, browserName: String,
                           browserAddressStatus: String, browserAutomationStatus: String, managedRuleAccountId: String,
                           browserHideFailed: Bool, appHideFailed: Bool, websitePolicyBrokerStatus: String, websiteProviderHealthy: Bool) {
    guard let defaults else { throw AppError.unavailable }
    let service = SMAppService.agent(plistName: plist).status
    let live = isMonitorRunning(defaults)
    let state = service == .requiresApproval ? "needsApproval" : service != .enabled ? "unavailable" : live ? "active" : "starting"
    let remaining = creditAllowed(defaults) ? max(0, defaults.double(forKey: "creditDeadlineMillis") - FilterCreditClock.nowMillis()) : 0
    let monitorRunning = isMonitorRunning(defaults)
    let brokerServiceStatus = BloomPolicyBrokerController.shared.status()
    let brokerSnapshotAccepted = defaults.bool(forKey: "monitorPolicyBrokerSnapshotAccepted")
    let brokerSnapshotAckMillis = (defaults.object(forKey: "monitorPolicyBrokerSnapshotAckMillis") as? NSNumber)?.doubleValue
    let brokerReady = BloomPolicyBrokerReadiness.isReady(serviceStatus: brokerServiceStatus,
      monitorRunning: monitorRunning, snapshotAccepted: brokerSnapshotAccepted,
      acknowledgementMillis: brokerSnapshotAckMillis, nowMillis: FilterCreditClock.nowMillis())
    let websitePolicyBrokerStatus = brokerServiceStatus == "active" && !brokerReady ? "unavailable" : brokerServiceStatus
    let accessibilityTrusted = defaults.bool(forKey: "monitorAccessibilityTrusted")
    let websiteUsageAvailable = brokerReady
    let providerHealthy = brokerReady && BloomPolicyBrokerReadiness.providerIsFresh(
      heartbeatMillis: (defaults.object(forKey: "filterProviderHeartbeatMillis") as? NSNumber)?.doubleValue,
      providerBoot: (defaults.object(forKey: "filterProviderHeartbeatBoot") as? NSNumber)?.int64Value,
      nowMillis: FilterCreditClock.nowMillis(), boot: FilterCreditClock.boot())
    let browserName = defaults.string(forKey: "monitorBrowserName") ?? ""
    let browserAddressStatus = defaults.string(forKey: "monitorBrowserAddressStatus") ?? "inactive"
    let browserAutomationStatus = defaults.string(forKey: "monitorBrowserAutomationStatus") ?? "notRequested"
    let managedRuleAccountId = defaults.string(forKey: "managedRuleAccountId") ?? ""
    let browserHideFailed = defaults.bool(forKey: "monitorBrowserHideFailed")
    let appHideFailed = defaults.bool(forKey: "monitorHideFailed")
    let apps = Set((defaults.stringArray(forKey: "blockedApps") ?? []) + (defaults.stringArray(forKey: "managedApps") ?? [])).sorted()
    let configured = defaults.bool(forKey: "appBlockingEnabled")
    return (configured && service == .enabled && live, configured,
      apps, state, remaining, websiteUsageAvailable, accessibilityTrusted, browserName,
      browserAddressStatus, browserAutomationStatus, managedRuleAccountId, browserHideFailed, appHideFailed,
      websitePolicyBrokerStatus, providerHealthy)
  }

  func start(apps: [String]) throws {
    guard let normalized = MacAppRules.normalize(apps), !normalized.isEmpty else { throw AppError.invalidApps }
    guard let defaults else { throw AppError.unavailable }
    guard SMAppService.agent(plistName: plist).status == .enabled && isMonitorRunning(defaults) else { throw AppError.serviceInactive }
    if creditAllowed(defaults) { throw AppError.sessionActive }
    if try usageStatus()?.closed == false { throw AppError.sessionActive }
    let managed = Set(defaults.stringArray(forKey: "managedApps") ?? [])
    guard MacSharedPreferences.write(["blockedApps": normalized.filter { !managed.contains($0) }, "appBlockingEnabled": true]) else { throw AppError.unavailable }
  }

  func syncManagedApps(_ apps: [String], accountId: String) throws -> String {
    guard let normalized = MacAppRules.normalize(apps), let defaults else { throw AppError.invalidApps }
    guard !accountId.isEmpty, accountId.count <= 64 else { throw AppError.invalidApps }
    let previous = defaults.stringArray(forKey: "managedApps") ?? []
    guard MacSharedPreferences.write(["managedRuleAccountId": accountId]) else { throw AppError.unavailable }
    if normalized.isEmpty && previous.isEmpty { return "inactive" }
    if normalized == previous {
      let unchangedStatus = SMAppService.agent(plistName: plist).status
      if !normalized.isEmpty && unchangedStatus == .notRegistered { _ = try ensureMonitor() }
      let current = SMAppService.agent(plistName: plist).status
      if current == .requiresApproval { return "needsApproval" }
      return current == .enabled ? "active" : "unavailable"
    }
    if !normalized.isEmpty { _ = try ensureMonitor() }
    let serviceStatus = SMAppService.agent(plistName: plist).status
    var updates: [String: Any] = ["managedApps": normalized]
    if !normalized.isEmpty && serviceStatus == .enabled {
      updates["appBlockingEnabled"] = true
    } else if normalized.isEmpty && !previous.isEmpty && (defaults.stringArray(forKey: "blockedApps") ?? []).isEmpty {
      updates["appBlockingEnabled"] = false
    }
    guard MacSharedPreferences.write(updates) else { throw AppError.unavailable }
    if serviceStatus == .requiresApproval { return "needsApproval" }
    return serviceStatus == .enabled ? "active" : "unavailable"
  }

  func managedApps() -> [String] { defaults?.stringArray(forKey: "managedApps") ?? [] }

  func clearManualApps() throws {
    guard let defaults else { throw AppError.unavailable }
    if defaults.bool(forKey: "appBlockingEnabled") { throw AppError.protectionActive }
    if creditAllowed(defaults) { throw AppError.sessionActive }
    if try usageStatus()?.closed == false { throw AppError.sessionActive }
    guard MacSharedPreferences.write(["blockedApps": []]) else { throw AppError.unavailable }
  }

  func stop() throws {
    guard let defaults else { throw AppError.unavailable }
    if !(defaults.stringArray(forKey: "managedApps") ?? []).isEmpty { throw AppError.parentRulesActive }
    if creditAllowed(defaults) { throw AppError.sessionActive }
    if try usageStatus()?.closed == false { throw AppError.sessionActive }
    guard MacSharedPreferences.write(["appBlockingEnabled": false]) else { throw AppError.unavailable }
  }

  func setCredit(deadline: Double, boot: Int64) throws {
    guard let defaults else { throw AppError.unavailable }
    guard defaults.bool(forKey: "appBlockingEnabled"), SMAppService.agent(plistName: plist).status == .enabled, isMonitorRunning(defaults) else { throw AppError.serviceInactive }
    if try usageStatus()?.closed == false { throw AppError.sessionActive }
    guard MacSharedPreferences.write(["creditBoot": NSNumber(value: boot), "creditDeadlineMillis": NSNumber(value: deadline)]) else { throw AppError.unavailable }
  }

  func clearCredit() throws {
    guard MacSharedPreferences.write(removing: ["creditBoot", "creditDeadlineMillis"]) else { throw AppError.unavailable }
  }

  func usageStatus() throws -> MacUsageState? {
    guard let defaults else { throw AppError.unavailable }
    let store = try MacUsageStore.shared()
    if !isMonitorRunning(defaults) { try store.recoverAfterInterruption() }
    return try store.read()
  }

  func startUsage(session: String, user: String, budget: Int64, expiry: Double, requestElapsed: Double, requestBoot: Int64) throws {
    try validateUsageReady()
    try MacUsageStore.shared().start(session: session, user: user, budget: budget, expiryIn: expiry,
      requestElapsed: requestElapsed, requestBoot: requestBoot)
  }

  func validateUsageReady() throws {
    guard let defaults,
          SMAppService.agent(plistName: plist).status == .enabled, isMonitorRunning(defaults) else { throw AppError.serviceInactive }
    let websiteTarget = defaults.bool(forKey: "websiteBlockingEnabled") && !(defaults.stringArray(forKey: "blockedDomains") ?? []).isEmpty
    let appTarget = defaults.bool(forKey: "appBlockingEnabled")
      && !(Set((defaults.stringArray(forKey: "blockedApps") ?? []) + (defaults.stringArray(forKey: "managedApps") ?? [])).isEmpty)
    guard websiteTarget || appTarget else { throw AppError.noTargets }
    if creditAllowed(defaults) { throw AppError.sessionActive }
  }

  func closeUsage(user: String) throws -> MacUsageState? {
    _ = try usageStatus()
    return try MacUsageStore.shared().close(user: user)
  }

  func clearUsage(user: String, session: String) throws {
    try MacUsageStore.shared().clear(user: user, session: session)
  }

  private func creditAllowed(_ defaults: UserDefaults) -> Bool {
    FilterCreditClock.isAllowed(configuration: ["creditBoot": defaults.object(forKey: "creditBoot") ?? NSNull(),
      "creditDeadlineMillis": defaults.object(forKey: "creditDeadlineMillis") ?? NSNull()])
  }

  private func isMonitorRunning(_ defaults: UserDefaults) -> Bool {
    let expectedMonitor = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/BloomAppMonitor").path
    guard MacAppRules.monitorMatches(reportedPath: defaults.string(forKey: "monitorExecutablePath"), expectedPath: expectedMonitor),
          let boot = FilterCreditClock.boot(), defaults.object(forKey: "monitorBoot") as? NSNumber == NSNumber(value: boot),
          let heartbeat = defaults.object(forKey: "monitorHeartbeatMillis") as? NSNumber else { return false }
    let elapsed = FilterCreditClock.nowMillis() - heartbeat.doubleValue
    return elapsed >= 0 && elapsed < 15000
  }

  private enum AppError: LocalizedError {
    case unavailable, invalidApps, serviceInactive, sessionActive, protectionActive, noTargets, parentRulesActive
    case monitorNotRegistered, monitorNotFound
    var errorDescription: String? {
      switch self {
      case .unavailable: return "Bloom's Mac app monitor is not configured."
      case .monitorNotRegistered: return "macOS did not register Bloom's background monitor. Restart Bloom and try again."
      case .monitorNotFound: return "macOS cannot find Bloom's bundled background monitor. Reinstall the signed Bloom app from Applications."
      case .invalidApps: return "Choose a valid app. Bloom keeps Finder, Dock, System Settings, Activity Monitor, Terminal, and the login window available for recovery."
      case .serviceInactive: return "Enable the Bloom background monitor first."
      case .sessionActive: return "Wait until screen time ends before changing app blocking."
      case .protectionActive: return "Stop app protection before clearing saved manual apps."
      case .noTargets: return "Start app or website blocking before using screen time."
      case .parentRulesActive: return "Parent-set app rules must remain enabled."
      }
    }
  }
}
