import ExpoModulesCore
import UIKit

#if os(iOS) && canImport(SafariServices)
import SafariServices
#endif

#if canImport(FamilyControls) && canImport(ManagedSettings)
import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI
import Darwin
#endif

public class BloomBlockingModule: Module {
  public func definition() -> ModuleDefinition {
    Name("BloomBlocking")

    Function("getStatus") {
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      BloomBlockingStore.reconcileCountdown()
      let selection = BloomBlockingStore.loadSelection()
      let authorized = BloomBlockingStore.authorized()
      let active = BloomBlockingStore.defaults?.bool(forKey: BloomBlockingStore.activeKey) == true
      let schedule = BloomScheduledFocusStore.currentStatus()
      return [
        "supported": true,
        "authorized": authorized,
        "active": (authorized && active) || BloomSafariBlocker.focusIsActive,
        "appCount": selection?.applicationTokens.count ?? 0,
        "websiteCount": selection?.webDomainTokens.count ?? 0,
        "categoryCount": selection?.categoryTokens.count ?? 0,
        "manualFocusActive": BloomManualFocusStore.activeAccount != nil,
        "scheduledActiveCount": schedule.activeCount,
        "scheduleError": schedule.error,
      ] as [String: Any]
      #else
      return ["supported": false, "authorized": false, "active": false, "appCount": 0, "websiteCount": 0, "categoryCount": 0] as [String: Any]
      #endif
    }

    AsyncFunction("getSafariContentBlockerState") { () async -> [String: Bool] in
      #if os(iOS) && canImport(SafariServices)
      return await BloomSafariBlocker.state()
      #else
      return ["bundled": false, "stateAvailable": false, "enabled": false]
      #endif
    }

    AsyncFunction("setSafariWebsiteRules") { (alwaysDomains: [String], focusDomains: [String], accountId: String) async throws -> [String: Any] in
      #if os(iOS) && canImport(SafariServices)
      let normalizedAlways = try BloomSafariBlocker.canonicalDomains(alwaysDomains)
      let normalizedFocus = try BloomSafariBlocker.canonicalDomains(focusDomains)
      try BloomSafariBlocker.save(alwaysDomains: normalizedAlways, focusDomains: normalizedFocus, accountId: accountId)
      let websiteStatus = BloomManagedWebsiteFilter.synchronize(alwaysDomains: normalizedAlways)
      await BloomSafariBlocker.reloadIgnoringErrors()
      return [
        "alwaysApplied": websiteStatus.alwaysApplied,
        "authorizationRequired": websiteStatus.authorizationRequired,
        "alwaysDomainCount": normalizedAlways.count,
      ]
      #else
      throw BlockingControlError.unavailable
      #endif
    }

    AsyncFunction("requestAuthorization") { () async throws -> Bool in
      #if canImport(FamilyControls)
      try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
      return BloomBlockingStore.authorized()
      #else
      return false
      #endif
    }

    AsyncFunction("presentPicker") { (promise: Promise) in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      DispatchQueue.main.async {
        guard BloomBlockingStore.authorized() else {
          promise.reject("AUTHORIZATION_REQUIRED", "Allow Screen Time access before choosing apps and websites.")
          return
        }
        guard BloomBlockingStore.countdownRemaining() <= 0 else {
          promise.reject("SESSION_ACTIVE", "Wait until screen time ends before changing blocked targets.")
          return
        }
        guard (try? BloomBlockingStore.usageExists()) == false else {
          promise.reject("SESSION_ACTIVE", "Sync your screen-time session before changing blocked targets.")
          return
        }
        guard let presenter = Self.topViewController() else {
          promise.reject("NO_PRESENTING_VIEW", "Bloom could not open the system selection screen.")
          return
        }
        let selection = BloomBlockingStore.loadSelection() ?? FamilyActivitySelection()
        let picker = UIHostingController(rootView: BloomActivityPicker(selection: selection) { newSelection in
          BloomBlockingStore.saveSelection(newSelection)
          if BloomBlockingStore.defaults?.bool(forKey: BloomBlockingStore.activeKey) == true {
            BloomBlockingStore.apply(newSelection)
            BloomBlockingStore.defaults?.set(BloomBlockingStore.hasTargets(newSelection), forKey: BloomBlockingStore.activeKey)
          }
          presenter.dismiss(animated: true) {
            promise.resolve([
              "appCount": newSelection.applicationTokens.count,
              "websiteCount": newSelection.webDomainTokens.count,
              "categoryCount": newSelection.categoryTokens.count,
              "cancelled": false,
            ])
          }
        } onCancel: {
          presenter.dismiss(animated: true) {
            let saved = BloomBlockingStore.loadSelection()
            promise.resolve([
              "appCount": saved?.applicationTokens.count ?? 0,
              "websiteCount": saved?.webDomainTokens.count ?? 0,
              "categoryCount": saved?.categoryTokens.count ?? 0,
              "cancelled": true,
            ])
          }
        })
        picker.modalPresentationStyle = .pageSheet
        picker.isModalInPresentation = true
        presenter.present(picker, animated: true)
      }
      #else
      promise.reject("UNAVAILABLE", "Screen Time controls are unavailable on this OS version.")
      #endif
    }

    AsyncFunction("setFocusAccount") { (accountId: String) throws -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      try BloomManualFocusStore.setAccount(accountId)
      BloomScheduledFocusStore.setAccount(accountId)
      #else
      throw BlockingControlError.unavailable
      #endif
    }

    Function("getFocusAccount") { () -> String? in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      return BloomBlockingStore.defaults?.string(forKey: "bloom_scheduled_focus_account")
        ?? BloomBlockingStore.defaults?.string(forKey: "bloom_manual_account")
      #else
      return nil
      #endif
    }

    AsyncFunction("clearFocusAccount") { (accountId: String) throws -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      try BloomManualFocusStore.clearAccount(accountId)
      try BloomScheduledFocusStore.clearAccount(accountId)
      #endif
    }

    Function("getIosFocusRoutines") { (accountId: String) throws -> String in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      try BloomScheduledFocusStore.json(accountId)
      #else
      throw BlockingControlError.unavailable
      #endif
    }

    Function("getIosFocusRoutineSelection") { (accountId: String, routineId: String) throws -> [String: Int] in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      let selection = try BloomScheduledFocusStore.selection(accountId, routineId)
      return ["appCount": selection.applicationTokens.count, "websiteCount": selection.webDomainTokens.count,
              "categoryCount": selection.categoryTokens.count]
      #else
      throw BlockingControlError.unavailable
      #endif
    }

    AsyncFunction("presentIosFocusRoutinePicker") { (accountId: String, routineId: String, promise: Promise) in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      DispatchQueue.main.async {
        guard BloomBlockingStore.authorized() else {
          promise.reject("AUTHORIZATION_REQUIRED", "Allow Screen Time access before choosing apps and websites.")
          return
        }
        guard let presenter = Self.topViewController() else {
          promise.reject("NO_PRESENTING_VIEW", "Bloom could not open the system selection screen.")
          return
        }
        do {
          let selection = try BloomScheduledFocusStore.selection(accountId, routineId)
          let picker = UIHostingController(rootView: BloomActivityPicker(selection: selection) { next in
            do {
              try BloomScheduledFocusStore.saveSelection(next, accountId: accountId, routineId: routineId)
              presenter.dismiss(animated: true) { promise.resolve(true) }
            } catch {
              presenter.dismiss(animated: true) { promise.reject("SCHEDULE_SELECTION_FAILED", error.localizedDescription) }
            }
          } onCancel: {
            presenter.dismiss(animated: true) { promise.resolve(false) }
          })
          picker.modalPresentationStyle = .pageSheet
          picker.isModalInPresentation = true
          presenter.present(picker, animated: true)
        } catch { promise.reject("SCHEDULE_ACCOUNT_UNAVAILABLE", error.localizedDescription) }
      }
      #else
      promise.reject("UNAVAILABLE", "Scheduled Focus is unavailable on this OS version.")
      #endif
    }

    AsyncFunction("saveIosFocusRoutine") { (accountId: String, raw: String) throws -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      try BloomScheduledFocusStore.save(accountId, raw: raw)
      #else
      throw BlockingControlError.unavailable
      #endif
    }

    AsyncFunction("deleteIosFocusRoutine") { (accountId: String, routineId: String) throws -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      try BloomScheduledFocusStore.delete(accountId, routineId)
      #else
      throw BlockingControlError.unavailable
      #endif
    }

    Function("getIosManualFocus") { (accountId: String) throws -> [String: Any] in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      let (selection, active) = try BloomManualFocusStore.state(accountId)
      return ["appCount": selection.applicationTokens.count, "websiteCount": selection.webDomainTokens.count,
              "categoryCount": selection.categoryTokens.count, "active": active] as [String: Any]
      #else
      throw BlockingControlError.unavailable
      #endif
    }

    AsyncFunction("presentIosManualPicker") { (accountId: String, promise: Promise) in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      DispatchQueue.main.async {
        guard BloomBlockingStore.authorized() else {
          promise.reject("AUTHORIZATION_REQUIRED", "Allow Screen Time access before choosing apps and websites.")
          return
        }
        guard let presenter = Self.topViewController() else {
          promise.reject("NO_PRESENTING_VIEW", "Bloom could not open the system selection screen.")
          return
        }
        do {
          let (selection, _) = try BloomManualFocusStore.state(accountId)
          let picker = UIHostingController(rootView: BloomActivityPicker(selection: selection) { next in
            do {
              try BloomManualFocusStore.save(next, accountId: accountId)
              presenter.dismiss(animated: true) { promise.resolve(true) }
            } catch {
              presenter.dismiss(animated: true) { promise.reject("MANUAL_SAVE_FAILED", error.localizedDescription) }
            }
          } onCancel: {
            presenter.dismiss(animated: true) { promise.resolve(false) }
          })
          picker.modalPresentationStyle = .pageSheet
          picker.isModalInPresentation = true
          presenter.present(picker, animated: true)
        } catch { promise.reject("MANUAL_ACCOUNT_UNAVAILABLE", error.localizedDescription) }
      }
      #else
      promise.reject("UNAVAILABLE", "Screen Time controls are unavailable on this OS version.")
      #endif
    }

    AsyncFunction("startIosManualFocus") { (accountId: String) throws -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      try BloomManualFocusStore.start(accountId)
      #else
      throw BlockingControlError.unavailable
      #endif
    }

    AsyncFunction("stopIosManualFocus") { (accountId: String) throws -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      try BloomManualFocusStore.stop(accountId)
      #endif
    }

    AsyncFunction("startBlocking") { () async throws -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      guard BloomBlockingStore.countdownRemaining() <= 0 else { throw BlockingControlError.sessionActive }
      guard try !BloomBlockingStore.usageExists() else { throw BlockingControlError.usageNeedsSync }
      guard BloomBlockingStore.defaults != nil else { throw BlockingControlError.appGroupUnavailable }
      let selection = BloomBlockingStore.loadSelection() ?? FamilyActivitySelection()
      let hasAppleTargets = BloomBlockingStore.hasTargets(selection)
      guard BloomBlockingStore.authorized() || BloomSafariBlocker.hasFocusDomains else {
        throw BlockingControlError.authorizationRequired
      }
      guard hasAppleTargets || BloomSafariBlocker.hasFocusDomains else {
        throw BlockingControlError.noTargets
      }
      if BloomBlockingStore.authorized() && hasAppleTargets { BloomBlockingStore.apply(selection) }
      else { BloomBlockingStore.clearShields() }
      BloomBlockingStore.defaults?.set(true, forKey: BloomBlockingStore.activeKey)
      BloomSafariBlocker.setFocusActive(true)
      await BloomSafariBlocker.reloadIgnoringErrors()
      #else
      throw BlockingControlError.unavailable
      #endif
    }

    Function("getCreditClock") { () throws -> [String: Any] in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      guard BloomBlockingStore.defaults != nil,
            let plugins = Bundle.main.builtInPlugInsURL,
            FileManager.default.fileExists(atPath: plugins.appendingPathComponent("BloomDeviceActivity.appex").path) else {
        throw BlockingControlError.appGroupUnavailable
      }
      return ["elapsedMillis": BloomBlockingStore.continuousMillis(), "boot": 1] as [String: Any]
      #else
      return ["elapsedMillis": 0, "boot": -1] as [String: Any]
      #endif
    }

    Function("getCreditAccessRemaining") {
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      BloomBlockingStore.reconcileCountdown()
      return BloomBlockingStore.countdownRemaining() * 1000
      #else
      return 0.0
      #endif
    }

    Function("getUsageAccess") { () throws -> [String: Any]? in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      return try BloomBlockingStore.usageStatus()
      #else
      return nil
      #endif
    }

    AsyncFunction("startUsageAccess") { (session: String, user: String, budget: Double, expiresIn: Double, requestElapsed: Double, requestBoot: Int) async throws -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      guard requestBoot == 1, budget.isFinite, expiresIn.isFinite, requestElapsed.isFinite,
            budget >= 1000, budget <= 604800000, expiresIn >= 1000, requestElapsed >= 0,
            BloomBlockingStore.defaults?.bool(forKey: BloomBlockingStore.activeKey) == true,
            BloomBlockingStore.authorized(),
            let selection = BloomBlockingStore.loadSelection(), BloomBlockingStore.hasTargets(selection) else { throw BlockingControlError.invalidDuration }
      let now = BloomBlockingStore.continuousMillis()
      let elapsedSinceRequest = now - requestElapsed
      let remaining = min(budget, expiresIn) - elapsedSinceRequest
      guard now >= requestElapsed, remaining >= 1000 else { throw BlockingControlError.invalidDuration }
      let startedAt = Date().addingTimeInterval(-elapsedSinceRequest / 1000)
      let expiry = Date().addingTimeInterval(remaining / 1000)
      try await BloomBlockingStore.startUsage(session: session, user: user, budget: Int64(budget),
        startedAt: startedAt, expiry: expiry, selection: selection)
      #else
      throw BlockingControlError.unavailable
      #endif
    }

    AsyncFunction("closeUsageAccess") { (user: String) async throws -> [String: Any]? in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      return try await BloomBlockingStore.closeUsage(user: user)
      #else
      return nil
      #endif
    }

    AsyncFunction("clearUsageAccess") { (user: String, session: String) throws -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      try BloomUsageFile.shared().mutate { state in
        guard let current = state else { return }
        guard current.userId == user, current.sessionId == session, current.closed, current.finalized else { throw BlockingControlError.sessionActive }
        state = nil
      }
      #endif
    }

    AsyncFunction("startCreditAccess") { (durationMillis: Double, requestElapsedMillis: Double, requestBoot: Int) async throws -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      guard requestBoot == 1, durationMillis.isFinite, requestElapsedMillis.isFinite,
            durationMillis >= 1000, durationMillis <= 86400000,
            requestElapsedMillis >= 0 else { throw BlockingControlError.invalidDuration }
      guard BloomBlockingStore.authorized(),
            BloomBlockingStore.defaults?.bool(forKey: BloomBlockingStore.activeKey) == true,
            let selection = BloomBlockingStore.loadSelection(), BloomBlockingStore.hasTargets(selection) else {
        throw BlockingControlError.authorizationRequired
      }
      guard try !BloomBlockingStore.usageExists() else { throw BlockingControlError.usageNeedsSync }
      let now = BloomBlockingStore.continuousMillis()
      guard now >= requestElapsedMillis else { throw BlockingControlError.invalidDuration }
      let remaining = durationMillis - (now - requestElapsedMillis)
      guard remaining >= 3000 else { throw BlockingControlError.invalidDuration }
      try await BloomBlockingStore.startCountdown(seconds: remaining / 1000, selection: selection)
      #else
      throw BlockingControlError.unavailable
      #endif
    }

    AsyncFunction("endCreditAccess") { () async -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      await BloomBlockingStore.endCountdown()
      #endif
    }

    AsyncFunction("stopBlocking") { () async throws -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      guard BloomBlockingStore.countdownRemaining() <= 0 else { throw BlockingControlError.sessionActive }
      guard try !BloomBlockingStore.usageExists() else { throw BlockingControlError.usageNeedsSync }
      BloomBlockingStore.clearShields()
      BloomBlockingStore.defaults?.set(false, forKey: BloomBlockingStore.activeKey)
      BloomSafariBlocker.setFocusActive(false)
      await BloomSafariBlocker.reloadIgnoringErrors()
      #endif
    }
  }

  private static func topViewController() -> UIViewController? {
    guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
          let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { return nil }
    var current = root
    while let presented = current.presentedViewController { current = presented }
    return current
  }
}

private enum BlockingControlError: LocalizedError {
  case authorizationRequired
  case noTargets
  case unavailable
  case sessionActive
  case usageNeedsSync
  case appGroupUnavailable
  case invalidDuration
  case invalidWebsite
  case tooManyWebsiteRules
  case accountMismatch

  var errorDescription: String? {
    switch self {
    case .authorizationRequired: return "Screen Time access is required to enable blocking."
    case .noTargets: return "Choose at least one app or website first."
    case .unavailable: return "Screen Time controls are unavailable on this OS version."
    case .sessionActive: return "Wait until screen time ends before changing blocking."
    case .usageNeedsSync: return "Finish and sync the screen-time session before changing blocking."
    case .appGroupUnavailable: return "Bloom's Screen Time extension is not configured for this app."
    case .invalidDuration: return "The screen-time session expired or could not be timed."
    case .invalidWebsite: return "Enter a valid website URL or domain."
    case .tooManyWebsiteRules: return "iOS allows up to 50 always-blocked domains and 1,000 Safari Focus domains."
    case .accountMismatch: return "Sync this device to your profile before managing Manual Focus."
    }
  }
}

#if os(iOS) && canImport(SafariServices)
private enum BloomSafariBlocker {
  static let alwaysRulesKey = "bloom_safari_always_domains"
  static let focusRulesKey = "bloom_safari_focus_domains"
  static let focusActiveKey = "bloom_safari_focus_active"
  static let focusSuspendedKey = "bloom_safari_focus_suspended"
  static let accountKey = "bloom_safari_website_rules_account"
  static let extensionSuffix = ".SafariContentBlocker"

  static var defaults: UserDefaults? {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "BloomAppGroup") as? String,
          FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil else { return nil }
    return UserDefaults(suiteName: group)
  }

  static var focusIsActive: Bool { defaults?.bool(forKey: focusActiveKey) == true }
  static var hasFocusDomains: Bool { !(defaults?.stringArray(forKey: focusRulesKey) ?? []).isEmpty }

  static func save(alwaysDomains: [String], focusDomains: [String], accountId: String) throws {
    guard UUID(uuidString: accountId) != nil, let defaults else { throw BlockingControlError.appGroupUnavailable }
    let always = try canonicalDomains(alwaysDomains)
    let focus = try canonicalDomains(focusDomains)
    guard always.count <= 50, focus.count <= 1000 else { throw BlockingControlError.tooManyWebsiteRules }
    let previousAccount = defaults.string(forKey: accountKey)
    if previousAccount == nil {
      defaults.set(defaults.bool(forKey: "bloom_blocking_active"), forKey: focusActiveKey)
    } else if previousAccount != accountId {
      defaults.set(false, forKey: focusActiveKey)
      defaults.set(false, forKey: focusSuspendedKey)
    }
    defaults.set(always, forKey: alwaysRulesKey)
    defaults.set(focus, forKey: focusRulesKey)
    defaults.set(accountId, forKey: accountKey)
    guard defaults.synchronize() else { throw BlockingControlError.appGroupUnavailable }
  }

  static func setFocusActive(_ active: Bool) {
    defaults?.set(active, forKey: focusActiveKey)
  }

  static func setFocusSuspended(_ suspended: Bool) {
    defaults?.set(suspended, forKey: focusSuspendedKey)
  }

  static func state() async -> [String: Bool] {
    let bundled = isExtensionBundled
    guard let identifier = extensionIdentifier else {
      return ["bundled": false, "stateAvailable": false, "enabled": false]
    }
    return await withCheckedContinuation { (continuation: CheckedContinuation<[String: Bool], Never>) in
      SFContentBlockerManager.getStateOfContentBlocker(withIdentifier: identifier) { state, error in
        continuation.resume(returning: [
          "bundled": bundled,
          "stateAvailable": state != nil && error == nil,
          "enabled": state?.isEnabled == true,
        ])
      }
    }
  }

  static func reloadIgnoringErrors() async {
    guard let identifier = extensionIdentifier else { return }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      SFContentBlockerManager.reloadContentBlocker(withIdentifier: identifier) { _ in continuation.resume() }
    }
  }

  private static var extensionIdentifier: String? {
    Bundle.main.bundleIdentifier.map { $0 + extensionSuffix }
  }

  private static var isExtensionBundled: Bool {
    guard let identifier = extensionIdentifier else { return false }
    let infoURL = Bundle.main.bundleURL
      .appendingPathComponent("PlugIns", isDirectory: true)
      .appendingPathComponent("BloomSafariContentBlocker.appex", isDirectory: true)
      .appendingPathComponent("Info.plist")
    guard let infoData = try? Data(contentsOf: infoURL),
          let propertyList = try? PropertyListSerialization.propertyList(from: infoData, options: [], format: nil),
          let extensionInfo = propertyList as? [String: Any],
          extensionInfo["CFBundleIdentifier"] as? String == identifier,
          let extensionDescription = extensionInfo["NSExtension"] as? [String: Any],
          extensionDescription["NSExtensionPointIdentifier"] as? String == "com.apple.Safari.content-blocker" else { return false }
    return true
  }

  static func canonicalDomains(_ values: [String]) throws -> [String] {
    var result = Set<String>()
    for value in values {
      guard let domain = canonicalDomain(value) else { throw BlockingControlError.invalidWebsite }
      result.insert(domain)
    }
    return result.sorted()
  }

  private static func canonicalDomain(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let urlString = trimmed.range(of: #"^[a-z][a-z0-9+.-]*://"#, options: [.regularExpression, .caseInsensitive]) == nil ? "https://\(trimmed)" : trimmed
    guard let components = URLComponents(string: urlString),
          let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
          components.user == nil, components.password == nil,
          let host = components.host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")),
          host.count <= 253 else { return nil }
    let labels = host.split(separator: ".", omittingEmptySubsequences: false)
    guard labels.count >= 2 else { return nil }
    for label in labels {
      guard label.count <= 63,
            label.range(of: #"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$"#, options: .regularExpression) != nil else { return nil }
    }
    return host
  }
}
#else
private enum BloomSafariBlocker {
  static var focusIsActive: Bool { false }
  static var hasFocusDomains: Bool { false }
  static func setFocusActive(_ active: Bool) {}
  static func setFocusSuspended(_ suspended: Bool) {}
  static func reloadIgnoringErrors() async {}
}
#endif

#if canImport(FamilyControls) && canImport(ManagedSettings)
@available(iOS 16.0, *)
private enum BloomManagedWebsiteFilter {
  private static let storeName = ManagedSettingsStore.Name("bloom.always.website.rules")

  static func synchronize(alwaysDomains: [String]) -> (alwaysApplied: Bool, authorizationRequired: Bool) {
    guard BloomBlockingStore.authorized() else {
      return (false, !alwaysDomains.isEmpty)
    }

    let store = ManagedSettingsStore(named: storeName)
    if alwaysDomains.isEmpty {
      store.webContent.blockedByFilter = nil
    } else {
      store.webContent.blockedByFilter = .specific(Set(alwaysDomains.map { WebDomain(domain: $0) }))
    }
    return (true, false)
  }
}

@available(iOS 16.0, *)
private enum BloomBlockingStore {
  static let selectionKey = "bloom_family_activity_selection"
  static let activeKey = "bloom_blocking_active"
  static let countdownEndKey = "bloom_countdown_end"
  static let countdownName = DeviceActivityName("bloom.countdown.expiry")

  static func authorized() -> Bool {
    let status = AuthorizationCenter.shared.authorizationStatus
    #if BLOOM_USAGE_DATA
    if #available(iOS 26.4, *), status == .approvedWithDataAccess { return true }
    #endif
    return status == .approved
  }

  static func usageExists() throws -> Bool {
    try BloomUsageFile.shared().mutate { state in state != nil }
  }

  static func usageStatus() throws -> [String: Any]? {
    try BloomUsageFile.shared().mutate { state in
      if var current = state {
        let wasOpen = !current.closed
        current.refresh(now: Date())
        if wasOpen && current.closed {
          if defaults?.bool(forKey: activeKey) == true, let selection = loadSelection() { apply(selection) }
          BloomSafariBlocker.setFocusSuspended(false)
          Task { await BloomSafariBlocker.reloadIgnoringErrors() }
        }
        state = current
      }
      return state?.response
    }
  }

  static func closeUsage(user: String) async throws -> [String: Any]? {
    let closed: BloomUsageState? = try BloomUsageFile.shared().mutate { state in
      guard var current = state else { return nil }
      guard current.userId == user else { throw BlockingControlError.sessionActive }
      current.finish(now: Date())
      if defaults?.bool(forKey: activeKey) == true, let selection = loadSelection() { apply(selection) }
      BloomSafariBlocker.setFocusSuspended(false)
      state = current
      return current
    }
    guard let closed else { return nil }
    DeviceActivityCenter().stopMonitoring([DeviceActivityName("bloom.usage.expiry.\(closed.sessionId)")])
    await BloomSafariBlocker.reloadIgnoringErrors()
    return closed.response
  }

  static func startUsage(session: String, user: String, budget: Int64, startedAt: Date, expiry: Date, selection: FamilyActivitySelection) async throws {
    guard UUID(uuidString: session) != nil, UUID(uuidString: user) != nil, startedAt <= Date(), expiry > Date() else { throw BlockingControlError.invalidDuration }
    let center = DeviceActivityCenter()
    let expiryMonitor = DeviceActivityName("bloom.usage.expiry.\(session)")
    let calendar = Calendar.current
    let components: Set<Calendar.Component> = [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second]
    let expirySchedule = DeviceActivitySchedule(intervalStart: calendar.dateComponents(components, from: expiry),
      intervalEnd: calendar.dateComponents(components, from: expiry.addingTimeInterval(16 * 60)), repeats: false)
    let file = try BloomUsageFile.shared()
    let created = try file.mutate { state -> Bool in
      if let existing = state {
        guard existing.sessionId == session, existing.userId == user, !existing.closed else { throw BlockingControlError.sessionActive }
        return false
      }
      state = BloomUsageState(sessionId: session, userId: user, budgetMillis: budget, expiry: expiry, startedAt: startedAt)
      return true
    }
    do {
      if created {
        try center.startMonitoring(expiryMonitor, during: expirySchedule)
      } else {
        guard center.activities.contains(expiryMonitor) else { throw BlockingControlError.sessionActive }
      }
      try file.mutate { state in
        guard let current = state, current.sessionId == session, !current.closed, current.expiry.timeIntervalSinceNow > 1 else { throw BlockingControlError.invalidDuration }
        BloomSafariBlocker.setFocusSuspended(true)
        clearShields()
      }
      await BloomSafariBlocker.reloadIgnoringErrors()
    } catch {
      center.stopMonitoring([expiryMonitor])
      try? file.mutate { state in
        if var current = state, current.sessionId == session {
          current.finish(now: Date())
          state = current
        }
      }
      BloomSafariBlocker.setFocusSuspended(false)
      await BloomSafariBlocker.reloadIgnoringErrors()
      apply(selection)
      throw error
    }
  }

  static var defaults: UserDefaults? {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "BloomAppGroup") as? String,
          FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil else { return nil }
    return UserDefaults(suiteName: group)
  }

  static func loadSelection() -> FamilyActivitySelection? {
    guard let data = defaults?.data(forKey: selectionKey) ?? UserDefaults.standard.data(forKey: selectionKey) else { return nil }
    return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
  }

  static func saveSelection(_ selection: FamilyActivitySelection) {
    guard let data = try? JSONEncoder().encode(selection) else { return }
    defaults?.set(data, forKey: selectionKey)
  }

  static func hasTargets(_ selection: FamilyActivitySelection) -> Bool {
    !selection.applicationTokens.isEmpty || !selection.webDomainTokens.isEmpty || !selection.categoryTokens.isEmpty
  }

  static func apply(_ selection: FamilyActivitySelection) {
    let store = ManagedSettingsStore()
    store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
  }

  static func clearShields() {
    let store = ManagedSettingsStore()
    store.shield.applications = nil
    store.shield.applicationCategories = nil
    store.shield.webDomains = nil
    store.shield.webDomainCategories = nil
  }

  static func continuousMillis() -> Double {
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    return Double(mach_continuous_time()) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000
  }

  static func countdownRemaining() -> TimeInterval {
    guard let end = defaults?.object(forKey: countdownEndKey) as? Date else { return 0 }
    return max(0, end.timeIntervalSinceNow)
  }

  static func reconcileCountdown() {
    guard let defaults = defaults, defaults.object(forKey: countdownEndKey) != nil, countdownRemaining() <= 0 else { return }
    if defaults.bool(forKey: activeKey), let selection = loadSelection() { apply(selection) }
    BloomSafariBlocker.setFocusSuspended(false)
    Task { await BloomSafariBlocker.reloadIgnoringErrors() }
    defaults.removeObject(forKey: countdownEndKey)
  }

  static func startCountdown(seconds: Double, selection: FamilyActivitySelection) async throws {
    guard let defaults = defaults else { throw BlockingControlError.appGroupUnavailable }
    saveSelection(selection)
    guard defaults.data(forKey: selectionKey) != nil, defaults.synchronize() else { throw BlockingControlError.appGroupUnavailable }
    // Device Activity intervals have a minimum duration; the interval starts at
    // the access deadline and lasts 16 minutes solely to schedule restoration.
    let end = Date(timeIntervalSince1970: floor(Date().addingTimeInterval(seconds).timeIntervalSince1970))
    let calendar = Calendar.current
    let components: Set<Calendar.Component> = [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second]
    let schedule = DeviceActivitySchedule(intervalStart: calendar.dateComponents(components, from: end),
      intervalEnd: calendar.dateComponents(components, from: end.addingTimeInterval(16 * 60)), repeats: false)
    guard let interval = schedule.nextInterval, abs(interval.start.timeIntervalSince(end)) < 1 else {
      throw BlockingControlError.invalidDuration
    }
    defaults.set(end, forKey: countdownEndKey)
    guard defaults.synchronize() else { throw BlockingControlError.appGroupUnavailable }
    do {
      try DeviceActivityCenter().startMonitoring(countdownName, during: schedule)
      guard end.timeIntervalSinceNow > 2 else { throw BlockingControlError.invalidDuration }
      BloomSafariBlocker.setFocusSuspended(true)
      clearShields()
      await BloomSafariBlocker.reloadIgnoringErrors()
    } catch {
      defaults.removeObject(forKey: countdownEndKey)
      DeviceActivityCenter().stopMonitoring([countdownName])
      BloomSafariBlocker.setFocusSuspended(false)
      await BloomSafariBlocker.reloadIgnoringErrors()
      apply(selection)
      throw error
    }
  }

  static func endCountdown() async {
    DeviceActivityCenter().stopMonitoring([countdownName])
    if defaults?.bool(forKey: activeKey) == true, let selection = loadSelection() { apply(selection) }
    BloomSafariBlocker.setFocusSuspended(false)
    defaults?.removeObject(forKey: countdownEndKey)
    await BloomSafariBlocker.reloadIgnoringErrors()
  }
}

// This named store is independent of the default store used by timed access.
// Apple combines active stores; clearing one cannot clear the others.
private enum BloomManualFocusStore {
  private static let accountKey = "bloom_manual_account"
  private static let activeKey = "bloom_manual_active_account"
  private static let selectionPrefix = "bloom_manual_selection:"
  private static let storeName = ManagedSettingsStore.Name("bloom.manual.focus")
  private static let lock = NSRecursiveLock()

  static var activeAccount: String? { BloomBlockingStore.defaults?.string(forKey: activeKey) }

  private static func checkedDefaults(_ accountId: String) throws -> UserDefaults {
    guard UUID(uuidString: accountId) != nil, let defaults = BloomBlockingStore.defaults else { throw BlockingControlError.appGroupUnavailable }
    guard defaults.string(forKey: accountKey) == accountId else { throw BlockingControlError.accountMismatch }
    return defaults
  }

  static func setAccount(_ accountId: String) throws {
    lock.lock(); defer { lock.unlock() }
    guard UUID(uuidString: accountId) != nil, let defaults = BloomBlockingStore.defaults else { throw BlockingControlError.appGroupUnavailable }
    if defaults.string(forKey: accountKey) != accountId {
      clearStore()
      defaults.removeObject(forKey: activeKey)
      defaults.set(accountId, forKey: accountKey)
      guard defaults.synchronize() else { throw BlockingControlError.appGroupUnavailable }
    }
  }

  static func clearAccount(_ accountId: String) throws {
    lock.lock(); defer { lock.unlock() }
    guard let defaults = BloomBlockingStore.defaults else { return }
    guard defaults.string(forKey: accountKey) == accountId else { return }
    clearStore()
    defaults.removeObject(forKey: activeKey)
    defaults.removeObject(forKey: accountKey)
    guard defaults.synchronize() else { throw BlockingControlError.appGroupUnavailable }
  }

  static func state(_ accountId: String) throws -> (FamilyActivitySelection, Bool) {
    lock.lock(); defer { lock.unlock() }
    let defaults = try checkedDefaults(accountId)
    let selection: FamilyActivitySelection
    if let data = defaults.data(forKey: selectionPrefix + accountId) {
      selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    } else { selection = FamilyActivitySelection() }
    return (selection, defaults.string(forKey: activeKey) == accountId)
  }

  static func save(_ selection: FamilyActivitySelection, accountId: String) throws {
    lock.lock(); defer { lock.unlock() }
    let defaults = try checkedDefaults(accountId)
    if defaults.string(forKey: activeKey) == accountId && !BloomBlockingStore.hasTargets(selection) { throw BlockingControlError.noTargets }
    let data = try JSONEncoder().encode(selection)
    defaults.set(data, forKey: selectionPrefix + accountId)
    guard defaults.synchronize() else { throw BlockingControlError.appGroupUnavailable }
    if defaults.string(forKey: activeKey) == accountId { apply(selection) }
  }

  static func start(_ accountId: String) throws {
    lock.lock(); defer { lock.unlock() }
    guard BloomBlockingStore.authorized() else { throw BlockingControlError.authorizationRequired }
    let defaults = try checkedDefaults(accountId)
    let (selection, _) = try state(accountId)
    guard BloomBlockingStore.hasTargets(selection) else { throw BlockingControlError.noTargets }
    defaults.set(accountId, forKey: activeKey)
    guard defaults.synchronize() else { throw BlockingControlError.appGroupUnavailable }
    apply(selection)
  }

  static func stop(_ accountId: String) throws {
    lock.lock(); defer { lock.unlock() }
    let defaults = try checkedDefaults(accountId)
    guard defaults.string(forKey: activeKey) == accountId else { return }
    clearStore()
    defaults.removeObject(forKey: activeKey)
    guard defaults.synchronize() else { throw BlockingControlError.appGroupUnavailable }
  }

  private static func apply(_ selection: FamilyActivitySelection) {
    let store = ManagedSettingsStore(named: storeName)
    store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
  }

  private static func clearStore() {
    let store = ManagedSettingsStore(named: storeName)
    store.shield.applications = nil
    store.shield.applicationCategories = nil
    store.shield.webDomains = nil
    store.shield.webDomainCategories = nil
  }
}

/// Each routine owns a named Managed Settings store, so overlapping schedules
/// and Manual Focus compose without clearing one another's restrictions.
private enum BloomScheduledFocusStore {
  private struct Routine: Codable {
    let id: String
    let name: String
    let enabled: Bool
    let startMinute: Int
    let endMinute: Int
    let days: [Int]
  }

  private static let accountKey = "bloom_scheduled_focus_account"
  private static let routinesPrefix = "bloom_scheduled_focus_routines:"
  private static let selectionPrefix = "bloom_scheduled_focus_selection:"
  private static let monitorPrefix = "bloom.sched."
  private static let storePrefix = "bloom.sched."
  private static let maximumEnabledRoutines = 18
  private static let lock = NSRecursiveLock()
  private static var timeObservers: [NSObjectProtocol] = []

  private static var center: DeviceActivityCenter { DeviceActivityCenter() }

  private static func defaults() throws -> UserDefaults {
    guard let defaults = BloomBlockingStore.defaults else { throw BlockingControlError.appGroupUnavailable }
    return defaults
  }

  private static func checkedDefaults(_ accountId: String) throws -> UserDefaults {
    guard UUID(uuidString: accountId) != nil else { throw BlockingControlError.accountMismatch }
    let defaults = try defaults()
    guard defaults.string(forKey: accountKey) == accountId else { throw BlockingControlError.accountMismatch }
    return defaults
  }

  private static func routinesKey(_ accountId: String) -> String { routinesPrefix + accountId }
  private static func selectionKey(_ accountId: String, _ routineId: String) -> String { selectionPrefix + accountId + ":" + routineId }
  private static func monitorName(_ accountId: String, _ routineId: String) -> DeviceActivityName {
    DeviceActivityName(monitorPrefix + accountId + "." + routineId)
  }
  private static func storeName(_ accountId: String, _ routineId: String) -> ManagedSettingsStore.Name {
    ManagedSettingsStore.Name(storePrefix + accountId + "." + routineId)
  }

  private static func load(_ accountId: String, defaults: UserDefaults) throws -> [Routine] {
    guard let data = defaults.data(forKey: routinesKey(accountId)) else { return [] }
    return try JSONDecoder().decode([Routine].self, from: data)
  }

  private static func persist(_ routines: [Routine], accountId: String, defaults: UserDefaults) throws {
    defaults.set(try JSONEncoder().encode(routines), forKey: routinesKey(accountId))
    guard defaults.synchronize() else { throw BlockingControlError.appGroupUnavailable }
  }

  static func setAccount(_ accountId: String) {
    lock.lock(); defer { lock.unlock() }
    observeTimeChanges()
    stopLegacySchedules()
    guard UUID(uuidString: accountId) != nil, let defaults = try? defaults() else { return }
    let previous = defaults.string(forKey: accountKey)
    if previous != accountId {
      if let previous { stopAndClear(previous, defaults: defaults) }
      defaults.set(accountId, forKey: accountKey)
      guard defaults.synchronize() else { return }
    }
    guard let routines = try? load(accountId, defaults: defaults) else { return }
    do {
      try registerMissing(routines, accountId: accountId)
      reconcile(routines, accountId: accountId)
    } catch {
      // Keep account sync available and expose the missing monitor via status.
    }
  }

  static func clearAccount(_ accountId: String) throws {
    lock.lock(); defer { lock.unlock() }
    stopLegacySchedules()
    let defaults = try defaults()
    guard defaults.string(forKey: accountKey) == accountId else { return }
    stopAndClear(accountId, defaults: defaults)
    defaults.removeObject(forKey: accountKey)
    guard defaults.synchronize() else { throw BlockingControlError.appGroupUnavailable }
  }

  private static func stopAndClear(_ accountId: String, defaults: UserDefaults) {
    guard let routines = try? load(accountId, defaults: defaults) else { return }
    let names = routines.map { monitorName(accountId, $0.id) }
    center.stopMonitoring(names)
    for routine in routines {
      clearStore(accountId, routine.id)
      clearLegacyStore(routine.id)
    }
  }

  private static func stopLegacySchedules() {
    let legacy = center.activities.filter { activity in
      let parts = activity.rawValue.split(separator: ".")
      return parts.count == 4 && parts[0] == "bloom" && parts[1] == "sched"
        && UUID(uuidString: String(parts[2])) != nil && Int(parts[3]) != nil
    }
    center.stopMonitoring(legacy)
    let routineIds = Set(legacy.compactMap { activity -> String? in
      let parts = activity.rawValue.split(separator: ".")
      return parts.count == 4 ? String(parts[2]) : nil
    })
    for routineId in routineIds {
      clearLegacyStore(routineId)
    }
  }

  private static func clearLegacyStore(_ routineId: String) {
    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(storePrefix + routineId))
    store.shield.applications = nil; store.shield.applicationCategories = nil
    store.shield.webDomains = nil; store.shield.webDomainCategories = nil
  }

  static func selection(_ accountId: String, _ routineId: String) throws -> FamilyActivitySelection {
    lock.lock(); defer { lock.unlock() }
    let defaults = try checkedDefaults(accountId)
    guard UUID(uuidString: routineId) != nil else { throw BlockingControlError.invalidDuration }
    guard let data = defaults.data(forKey: selectionKey(accountId, routineId)) else { return FamilyActivitySelection() }
    return try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
  }

  static func saveSelection(_ selection: FamilyActivitySelection, accountId: String, routineId: String) throws {
    lock.lock(); defer { lock.unlock() }
    let defaults = try checkedDefaults(accountId)
    guard UUID(uuidString: routineId) != nil else { throw BlockingControlError.invalidDuration }
    defaults.set(try JSONEncoder().encode(selection), forKey: selectionKey(accountId, routineId))
    guard defaults.synchronize() else { throw BlockingControlError.appGroupUnavailable }
    if let routines = try? load(accountId, defaults: defaults), routines.contains(where: { $0.id == routineId && $0.enabled }) {
      reconcile(routines, accountId: accountId)
    }
  }

  static func save(_ accountId: String, raw: String) throws {
    lock.lock(); defer { lock.unlock() }
    let defaults = try checkedDefaults(accountId)
    guard let data = raw.data(using: .utf8),
          let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let id = object["id"] as? String, UUID(uuidString: id) != nil,
          let rawName = object["name"] as? String,
          let enabled = object["enabled"] as? Bool,
          let start = object["startMinute"] as? Int,
          let end = object["endMinute"] as? Int,
          let rawDays = object["days"] as? [Int] else { throw BlockingControlError.invalidDuration }
    let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    let days = Array(Set(rawDays)).sorted()
    let durationMinutes = (end - start + 1440) % 1440
    guard !name.isEmpty, name.count <= 80, start >= 0, start < 1440, end >= 0, end < 1440,
          durationMinutes >= 15, !days.isEmpty, days.allSatisfy({ (0...6).contains($0) }) else { throw BlockingControlError.invalidDuration }
    let selected = try selection(accountId, id)
    guard BloomBlockingStore.hasTargets(selected) else { throw BlockingControlError.noTargets }
    if enabled && !BloomBlockingStore.authorized() { throw BlockingControlError.authorizationRequired }

    let previous = try load(accountId, defaults: defaults)
    let routine = Routine(id: id, name: name, enabled: enabled, startMinute: start, endMinute: end, days: days)
    let next = previous.filter { $0.id != id } + [routine]
    guard next.filter(\.enabled).count <= maximumEnabledRoutines else {
      throw NSError(domain: "BloomBlocking", code: 1, userInfo: [NSLocalizedDescriptionKey: "iOS supports up to 18 enabled Scheduled Focus routines on this device."])
    }
    try persist(next, accountId: accountId, defaults: defaults)
    do {
      center.stopMonitoring([monitorName(accountId, id)])
      clearStore(accountId, id)
      try register(routine, accountId: accountId)
      reconcile(next, accountId: accountId)
    } catch {
      try? persist(previous, accountId: accountId, defaults: defaults)
      center.stopMonitoring([monitorName(accountId, id)])
      clearStore(accountId, id)
      for old in previous where old.enabled { try? register(old, accountId: accountId) }
      reconcile(previous, accountId: accountId)
      throw error
    }
  }

  static func delete(_ accountId: String, _ routineId: String) throws {
    lock.lock(); defer { lock.unlock() }
    let defaults = try checkedDefaults(accountId)
    guard UUID(uuidString: routineId) != nil else { throw BlockingControlError.invalidDuration }
    let previous = try load(accountId, defaults: defaults)
    let next = previous.filter { $0.id != routineId }
    try persist(next, accountId: accountId, defaults: defaults)
    center.stopMonitoring([monitorName(accountId, routineId)])
    clearStore(accountId, routineId)
    defaults.removeObject(forKey: selectionKey(accountId, routineId))
    reconcile(next, accountId: accountId)
  }

  static func json(_ accountId: String) throws -> String {
    lock.lock(); defer { lock.unlock() }
    let defaults = try checkedDefaults(accountId)
    let routines = try load(accountId, defaults: defaults)
    let activeIds = Set(activeRoutines(routines).map(\.id))
    let rows = try routines.map { routine -> [String: Any] in
      let selected = try selection(accountId, routine.id)
      return ["id": routine.id, "name": routine.name, "enabled": routine.enabled,
              "startMinute": routine.startMinute, "endMinute": routine.endMinute,
              "days": routine.days, "appCount": selected.applicationTokens.count,
              "websiteCount": selected.webDomainTokens.count, "categoryCount": selected.categoryTokens.count,
              "active": activeIds.contains(routine.id)]
    }
    let data = try JSONSerialization.data(withJSONObject: rows)
    guard let result = String(data: data, encoding: .utf8) else { throw BlockingControlError.appGroupUnavailable }
    return result
  }

  static func currentStatus() -> (activeCount: Int, error: Bool) {
    guard let defaults = try? defaults(), let accountId = defaults.string(forKey: accountKey),
          let routines = try? load(accountId, defaults: defaults) else { return (0, false) }
    let expected = routines.filter(\.enabled).map { monitorName(accountId, $0.id) }
    let registered = Set(center.activities)
    let hasMissingMonitor = expected.contains(where: { !registered.contains($0) })
    return (activeRoutines(routines).count, hasMissingMonitor)
  }

  private static func registerMissing(_ routines: [Routine], accountId: String) throws {
    let registered = Set(center.activities)
    for routine in routines where routine.enabled {
      let name = monitorName(accountId, routine.id)
      if !registered.contains(name) { try center.startMonitoring(name, during: schedule(routine)) }
    }
  }

  private static func register(_ routine: Routine, accountId: String) throws {
    guard routine.enabled else { return }
    try center.startMonitoring(monitorName(accountId, routine.id), during: schedule(routine))
  }

  private static func schedule(_ routine: Routine) -> DeviceActivitySchedule {
    var start = DateComponents(); start.calendar = Calendar.current; start.timeZone = TimeZone.current
    start.hour = routine.startMinute / 60; start.minute = routine.startMinute % 60
    var end = DateComponents(); end.calendar = Calendar.current; end.timeZone = TimeZone.current
    end.hour = routine.endMinute / 60; end.minute = routine.endMinute % 60
    return DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true)
  }

  private static func activeRoutines(_ routines: [Routine], now: Date = Date()) -> [Routine] {
    let calendar = Calendar.current
    let day = calendar.component(.weekday, from: now) - 1
    let minute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
    return routines.filter { routine in
      guard routine.enabled else { return false }
      if routine.startMinute < routine.endMinute { return routine.days.contains(day) && minute >= routine.startMinute && minute < routine.endMinute }
      return (routine.days.contains(day) && minute >= routine.startMinute) ||
        (routine.days.contains((day + 6) % 7) && minute < routine.endMinute)
    }
  }

  private static func reconcile(_ routines: [Routine], accountId: String) {
    let active = Set(activeRoutines(routines).map(\.id))
    for routine in routines {
      if active.contains(routine.id),
         let data = try? defaults().data(forKey: selectionKey(accountId, routine.id)),
         let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
        apply(selection, accountId: accountId, routineId: routine.id)
      } else { clearStore(accountId, routine.id) }
    }
  }

  private static func apply(_ selection: FamilyActivitySelection, accountId: String, routineId: String) {
    let store = ManagedSettingsStore(named: storeName(accountId, routineId))
    store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
  }

  static func applyFromMonitor(_ expectedAccountId: String, routineId: String) {
    guard let defaults = try? defaults(), defaults.string(forKey: accountKey) == expectedAccountId,
          let accountId = defaults.string(forKey: accountKey),
          let routines = try? load(accountId, defaults: defaults),
          activeRoutines(routines).contains(where: { $0.id == routineId && $0.enabled }),
          let data = defaults.data(forKey: selectionKey(accountId, routineId)),
          let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
    apply(selection, accountId: accountId, routineId: routineId)
  }

  static func clearFromMonitor(_ accountId: String, routineId: String) { clearStore(accountId, routineId) }

  private static func clearStore(_ accountId: String, _ routineId: String) {
    let store = ManagedSettingsStore(named: storeName(accountId, routineId))
    store.shield.applications = nil; store.shield.applicationCategories = nil
    store.shield.webDomains = nil; store.shield.webDomainCategories = nil
  }

  private static func observeTimeChanges() {
    guard timeObservers.isEmpty else { return }
    let center = NotificationCenter.default
    timeObservers = [
      center.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main) { _ in refreshForLocalTimeChange() },
      center.addObserver(forName: UIApplication.significantTimeChangeNotification, object: nil, queue: .main) { _ in refreshForLocalTimeChange() },
      center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in refreshForLocalTimeChange() },
    ]
  }

  private static func refreshForLocalTimeChange() {
    lock.lock(); defer { lock.unlock() }
    guard let defaults = try? defaults(), let accountId = defaults.string(forKey: accountKey),
          let routines = try? load(accountId, defaults: defaults) else { return }
    let names = routines.filter(\.enabled).map { monitorName(accountId, $0.id) }
    center.stopMonitoring(names)
    for routine in routines where routine.enabled { try? register(routine, accountId: accountId) }
    reconcile(routines, accountId: accountId)
  }
}

@available(iOS 16.0, *)
private struct BloomActivityPicker: View {
  let onSave: (FamilyActivitySelection) -> Void
  let onCancel: () -> Void
  @State private var selection: FamilyActivitySelection

  init(selection: FamilyActivitySelection, onSave: @escaping (FamilyActivitySelection) -> Void, onCancel: @escaping () -> Void) {
    _selection = State(initialValue: selection)
    self.onSave = onSave
    self.onCancel = onCancel
  }

  var body: some View {
    NavigationStack {
      FamilyActivityPicker(
        headerText: nil,
        footerText: "Open Websites to choose a domain, then tap Save.",
        selection: $selection
      )
        .navigationTitle("Choose what to block")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) { Button("Cancel", action: onCancel) }
          ToolbarItem(placement: .topBarTrailing) { Button("Save") { onSave(selection) }.fontWeight(.semibold) }
        }
    }
  }
}
#endif
