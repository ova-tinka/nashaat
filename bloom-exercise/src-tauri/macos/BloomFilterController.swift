import Foundation
import NetworkExtension
import SystemExtensions

/// Host-side operations for the macOS system extension. A Tauri bridge still needs to call these.
@MainActor
final class BloomFilterController: NSObject, @preconcurrency OSSystemExtensionRequestDelegate {
  static let shared = BloomFilterController()
  static let extensionIdentifier = "com.focusflow.focusFlowFlutter.filter"

  enum Activation: String, Equatable {
    case active, needsApproval, needsRestart, needsBrokerApproval
  }

  private var pending: CheckedContinuation<Activation, Error>?
  private(set) var activationInProgress = false
  private(set) var activation: Activation?
  private(set) var lastError: String?

  func activate() async throws -> Activation {
    let monitorStatus = try BloomAppController.shared.ensureMonitor()
    if monitorStatus == "needsApproval" { throw FilterError.monitorNeedsApproval }
    guard monitorStatus == "active" else { throw FilterError.websitePolicyNotReady }

    let brokerStatus = try BloomPolicyBrokerController.shared.ensureRegistered()
    if brokerStatus == "needsApproval" { return .needsBrokerApproval }
    guard brokerStatus == "active" else { throw FilterError.policyBrokerUnavailable }
    guard await BloomAppController.shared.waitForWebsitePolicyReady() else {
      throw FilterError.websitePolicyNotReady
    }
    if !BloomFilterActivationPolicy.shouldSubmitRequest(alreadyActive: activation == .active) {
      return .active
    }
    guard !activationInProgress else { throw FilterError.requestInProgress }
    activationInProgress = true
    lastError = nil
    return try await withCheckedThrowingContinuation { continuation in
      pending = continuation
      let request = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: Self.extensionIdentifier, queue: .main)
      request.delegate = self
      OSSystemExtensionManager.shared.submitRequest(request)
    }
  }

  func start(domains: [String]) async throws {
    guard !domains.isEmpty, domains.count <= 500 else { throw FilterError.invalidDomains }
    let normalized = domains.compactMap(WebsiteRules.host)
    guard normalized.count == domains.count else { throw FilterError.invalidDomains }
    guard let defaults = appGroupDefaults() else { throw FilterError.unavailable }
    guard BloomPolicyBrokerController.shared.status() == "active" else { throw FilterError.policyBrokerUnavailable }
    let managed = defaults.stringArray(forKey: "managedDomains") ?? []
    let managedSet = Set(managed)
    let manual = Set(normalized.filter { !managedSet.contains($0) }).sorted()
    let effective = Set(normalized + managed).sorted()

    let manager = NEFilterManager.shared()
    try await manager.loadFromPreferences()
    if FilterCreditClock.isAllowed(configuration: manager.providerConfiguration?.vendorConfiguration) { throw FilterError.sessionActive }
    if manager.isEnabled && manager.providerConfiguration?.filterDataProviderBundleIdentifier != Self.extensionIdentifier {
      throw FilterError.anotherFilterActive
    }
    let configuration = NEFilterProviderConfiguration()
    configuration.filterDataProviderBundleIdentifier = Self.extensionIdentifier
    configuration.filterSockets = true
    configuration.vendorConfiguration = ["blockedDomains": effective]
    manager.providerConfiguration = configuration
    manager.localizedDescription = "Bloom website blocking"
    manager.isEnabled = true
    let oldManual = defaults.stringArray(forKey: "manualDomains")
    let oldDomains = defaults.stringArray(forKey: "blockedDomains")
    let oldEnabled = defaults.object(forKey: "websiteBlockingEnabled")
    guard MacSharedPreferences.write(["manualDomains": manual, "blockedDomains": effective, "websiteBlockingEnabled": true]) else { throw FilterError.unavailable }
    do {
      try await manager.saveToPreferences()
    } catch {
      var restored: [String: Any] = [:]
      var removed: [String] = []
      for (key, value) in [("manualDomains", oldManual as Any?), ("blockedDomains", oldDomains as Any?), ("websiteBlockingEnabled", oldEnabled)] {
        if let value { restored[key] = value } else { removed.append(key) }
      }
      _ = MacSharedPreferences.write(restored, removing: removed)
      throw error
    }
  }

  func stop() async throws {
    let manager = NEFilterManager.shared()
    try await manager.loadFromPreferences()
    guard manager.providerConfiguration?.filterDataProviderBundleIdentifier == Self.extensionIdentifier else { return }
    if FilterCreditClock.isAllowed(configuration: manager.providerConfiguration?.vendorConfiguration) { throw FilterError.sessionActive }
    if let usage = try? BloomAppController.shared.usageStatus(), !usage.closed { throw FilterError.sessionActive }
    if !(appGroupDefaults()?.stringArray(forKey: "managedDomains") ?? []).isEmpty { throw FilterError.parentRulesActive }
    manager.isEnabled = false
    try await manager.saveToPreferences()
    guard MacSharedPreferences.write(["websiteBlockingEnabled": false], removing: ["usageTargetDomain"]) else { throw FilterError.unavailable }
  }

  func clearManualDomains() async throws {
    guard let defaults = appGroupDefaults() else { throw FilterError.unavailable }
    let manager = NEFilterManager.shared()
    try await manager.loadFromPreferences()
    guard let configuration = manager.providerConfiguration else {
      guard MacSharedPreferences.write(["manualDomains": [], "blockedDomains": [], "websiteBlockingEnabled": false],
        removing: ["usageTargetDomain"]) else { throw FilterError.unavailable }
      return
    }
    guard configuration.filterDataProviderBundleIdentifier == Self.extensionIdentifier else { throw FilterError.anotherFilterActive }
    let activeCredit = FilterCreditClock.isAllowed(configuration: configuration.vendorConfiguration)
    let usage = try BloomAppController.shared.usageStatus()
    let openUsage = usage?.closed == false
    guard BloomWebsiteCleanupPolicy.mayClear(activeProtection: manager.isEnabled, activeCredit: activeCredit, openUsage: openUsage) else {
      if manager.isEnabled { throw FilterError.filterActive }
      throw FilterError.sessionActive
    }

    let managed = BloomWebsiteCleanupPolicy.retainedDomains(managedDomains: defaults.stringArray(forKey: "managedDomains") ?? [])
    var vendor = configuration.vendorConfiguration ?? [:]
    vendor["blockedDomains"] = managed
    configuration.vendorConfiguration = vendor
    manager.providerConfiguration = configuration
    try await manager.saveToPreferences()
    guard MacSharedPreferences.write(["manualDomains": [], "blockedDomains": managed, "websiteBlockingEnabled": false],
      removing: ["usageTargetDomain"]) else { throw FilterError.unavailable }
  }

  func status() async throws -> (enabled: Bool, domains: [String], remainingMillis: Double) {
    let manager = NEFilterManager.shared()
    try await manager.loadFromPreferences()
    guard let configuration = manager.providerConfiguration,
          configuration.filterDataProviderBundleIdentifier == Self.extensionIdentifier else { return (false, [], 0) }
    let vendor = configuration.vendorConfiguration
    let remaining = FilterCreditClock.isAllowed(configuration: vendor)
      ? max(0, ((vendor?["creditDeadlineMillis"] as? NSNumber)?.doubleValue ?? 0) - FilterCreditClock.nowMillis()) : 0
    return (manager.isEnabled, vendor?["blockedDomains"] as? [String] ?? [], remaining)
  }

  func managedDomains() -> [String] { appGroupDefaults()?.stringArray(forKey: "managedDomains") ?? [] }
  func manualDomains() throws -> [String] {
    guard let defaults = appGroupDefaults() else { throw FilterError.unavailable }
    return defaults.stringArray(forKey: "manualDomains") ?? []
  }

  func syncManagedDomains(_ domains: [String], accountId: String) async throws -> String {
    guard domains.count <= 500 else { throw FilterError.invalidDomains }
    let normalized = domains.compactMap(WebsiteRules.host)
    guard normalized.count == domains.count, !accountId.isEmpty, accountId.count <= 64,
          let defaults = appGroupDefaults() else { throw FilterError.invalidDomains }
    let manager = NEFilterManager.shared()
    try await manager.loadFromPreferences()
    if manager.isEnabled && manager.providerConfiguration?.filterDataProviderBundleIdentifier != Self.extensionIdentifier {
      throw FilterError.anotherFilterActive
    }
    let previousManaged = defaults.stringArray(forKey: "managedDomains") ?? []
    let configured = manager.providerConfiguration?.filterDataProviderBundleIdentifier == Self.extensionIdentifier
      ? manager.providerConfiguration?.vendorConfiguration?["blockedDomains"] as? [String] ?? [] : []
    let manual = defaults.stringArray(forKey: "manualDomains") ?? configured.filter { !previousManaged.contains($0) }
    let effective = Set(manual + normalized).sorted()
    guard MacSharedPreferences.write(["managedDomains": normalized, "manualDomains": manual, "blockedDomains": effective, "managedRuleAccountId": accountId]) else { throw FilterError.unavailable }

    if !effective.isEmpty {
      let brokerStatus = try BloomPolicyBrokerController.shared.ensureRegistered()
      if brokerStatus == "needsApproval" { return "needsBrokerApproval" }
      guard brokerStatus == "active" else { throw FilterError.policyBrokerUnavailable }
    }

    if normalized == previousManaged && effective == configured
      && manager.isEnabled == !effective.isEmpty {
      return effective.isEmpty ? "disabled" : "active"
    }

    guard !effective.isEmpty else {
      if manager.providerConfiguration?.filterDataProviderBundleIdentifier == Self.extensionIdentifier {
        manager.isEnabled = false
        try await manager.saveToPreferences()
      }
      guard MacSharedPreferences.write(["websiteBlockingEnabled": false], removing: ["usageTargetDomain"]) else { throw FilterError.unavailable }
      return "disabled"
    }

    if normalized.isEmpty {
      guard manager.isEnabled,
            manager.providerConfiguration?.filterDataProviderBundleIdentifier == Self.extensionIdentifier else {
        guard MacSharedPreferences.write(["websiteBlockingEnabled": false]) else { throw FilterError.unavailable }
        return "disabled"
      }
      let configuration = manager.providerConfiguration!
      var vendor = configuration.vendorConfiguration ?? [:]
      vendor["blockedDomains"] = effective
      configuration.vendorConfiguration = vendor
      manager.providerConfiguration = configuration
      try await manager.saveToPreferences()
      guard MacSharedPreferences.write(["websiteBlockingEnabled": true]) else { throw FilterError.unavailable }
      return "active"
    }

    switch try await activate() {
    case .needsApproval: return "needsApproval"
    case .needsRestart: return "needsRestart"
    case .needsBrokerApproval: return "needsBrokerApproval"
    case .active: break
    }
    let configuration: NEFilterProviderConfiguration
    if manager.providerConfiguration?.filterDataProviderBundleIdentifier == Self.extensionIdentifier,
       let existing = manager.providerConfiguration {
      configuration = existing
    } else {
      configuration = NEFilterProviderConfiguration()
    }
    configuration.filterDataProviderBundleIdentifier = Self.extensionIdentifier
    configuration.filterSockets = true
    var vendor = configuration.vendorConfiguration ?? [:]
    vendor["blockedDomains"] = effective
    configuration.vendorConfiguration = vendor
    manager.providerConfiguration = configuration
    manager.localizedDescription = "Bloom website blocking"
    manager.isEnabled = true
    try await manager.saveToPreferences()
    guard MacSharedPreferences.write(["websiteBlockingEnabled": true]) else { throw FilterError.unavailable }
    return "active"
  }

  func startCreditAccess(deadlineMillis: Double, boot: Int64) async throws {
    guard let currentBoot = FilterCreditClock.boot(), currentBoot == boot else { throw FilterError.invalidDuration }
    let now = FilterCreditClock.nowMillis()
    guard deadlineMillis.isFinite, deadlineMillis > now, deadlineMillis - now <= 86_400_000 else { throw FilterError.invalidDuration }
    let manager = NEFilterManager.shared()
    try await manager.loadFromPreferences()
    guard manager.isEnabled, let configuration = manager.providerConfiguration,
          configuration.filterDataProviderBundleIdentifier == Self.extensionIdentifier else { throw FilterError.filterInactive }
    guard let sites = configuration.vendorConfiguration?["blockedDomains"] as? [String], !sites.isEmpty else { throw FilterError.invalidDomains }
    var vendor = configuration.vendorConfiguration ?? [:]
    vendor["creditBoot"] = NSNumber(value: boot)
    vendor["creditDeadlineMillis"] = NSNumber(value: deadlineMillis)
    configuration.vendorConfiguration = vendor
    manager.providerConfiguration = configuration
    try await manager.saveToPreferences()
    // The foreground browser monitor reads the same deadline from the app
    // group, including when only websites (not apps) are protected.
    guard MacSharedPreferences.write(["creditBoot": NSNumber(value: boot), "creditDeadlineMillis": NSNumber(value: deadlineMillis)]) else { throw FilterError.unavailable }
  }

  func endCreditAccess() async throws {
    let manager = NEFilterManager.shared()
    try await manager.loadFromPreferences()
    guard let configuration = manager.providerConfiguration,
          configuration.filterDataProviderBundleIdentifier == Self.extensionIdentifier else { return }
    var vendor = configuration.vendorConfiguration ?? [:]
    vendor.removeValue(forKey: "creditBoot")
    vendor.removeValue(forKey: "creditDeadlineMillis")
    configuration.vendorConfiguration = vendor
    manager.providerConfiguration = configuration
    try await manager.saveToPreferences()
    guard MacSharedPreferences.write(removing: ["creditBoot", "creditDeadlineMillis"]) else { throw FilterError.unavailable }
  }

  func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
    finish(.success(.needsApproval), completed: false)
  }

  func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
    finish(.success(result == .willCompleteAfterReboot ? .needsRestart : .active), completed: true)
  }

  func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
    let detail = error as NSError
    if detail.domain == OSSystemExtensionErrorDomain && detail.code == OSSystemExtensionError.Code.codeSignatureInvalid.rawValue {
      finish(.failure(FilterError.invalidSignature), completed: true)
    } else {
      finish(.failure(error), completed: true)
    }
  }

  func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension extensionProperties: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
    .replace
  }

  private func finish(_ result: Result<Activation, Error>, completed: Bool) {
    if completed { activationInProgress = false }
    switch result {
    case .success(let value): activation = value
    case .failure(let error): lastError = error.localizedDescription
    }
    let continuation = pending
    pending = nil
    continuation?.resume(with: result)
  }

  private func appGroupDefaults() -> UserDefaults? {
    guard let group = BloomAppGroup.identifier,
          FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil else { return nil }
    return UserDefaults(suiteName: group)
  }

  private enum FilterError: LocalizedError {
    case requestInProgress, invalidDomains, anotherFilterActive, filterActive, sessionActive, invalidDuration, filterInactive, unavailable, parentRulesActive, invalidSignature, policyBrokerUnavailable, monitorNeedsApproval, websitePolicyNotReady
    var errorDescription: String? {
      switch self {
      case .invalidSignature: return "macOS rejected Bloom’s system extension signature. Check the signed app and its notarization before trying again."
      case .policyBrokerUnavailable: return "Approve Bloom’s website policy broker in System Settings before starting website protection."
      case .monitorNeedsApproval: return "Approve Bloom’s background monitor in System Settings → General → Login Items & Extensions before starting website protection."
      case .websitePolicyNotReady: return "Bloom’s website monitor has not checked in from this installation yet. Keep Bloom open and try again."
      case .requestInProgress: return "Bloom is already setting up website blocking."
      case .invalidDomains: return "Choose at least one valid website domain."
      case .anotherFilterActive: return "Another content filter is active. Turn it off before enabling Bloom's filter."
      case .filterActive: return "Stop website protection before clearing saved domains."
      case .sessionActive: return "Wait until screen time ends before changing website blocking."
      case .invalidDuration: return "The screen-time session expired or could not be timed."
      case .filterInactive: return "Start website blocking before using screen time."
      case .unavailable: return "Bloom's Mac settings store is unavailable."
      case .parentRulesActive: return "Parent-set website rules must remain enabled."
      }
    }
  }
}
