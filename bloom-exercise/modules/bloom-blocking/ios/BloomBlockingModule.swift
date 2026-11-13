import ExpoModulesCore
import UIKit

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
      return [
        "supported": true,
        "authorized": authorized,
        "active": authorized && BloomBlockingStore.defaults?.bool(forKey: BloomBlockingStore.activeKey) == true,
        "appCount": selection?.applicationTokens.count ?? 0,
        "websiteCount": selection?.webDomainTokens.count ?? 0,
        "categoryCount": selection?.categoryTokens.count ?? 0,
      ] as [String: Any]
      #else
      return ["supported": false, "authorized": false, "active": false, "appCount": 0, "websiteCount": 0, "categoryCount": 0] as [String: Any]
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

    AsyncFunction("startBlocking") { () throws -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      guard BloomBlockingStore.authorized() else {
        throw BlockingControlError.authorizationRequired
      }
      guard BloomBlockingStore.countdownRemaining() <= 0 else { throw BlockingControlError.sessionActive }
      guard try !BloomBlockingStore.usageExists() else { throw BlockingControlError.usageNeedsSync }
      guard BloomBlockingStore.defaults != nil else { throw BlockingControlError.appGroupUnavailable }
      guard let selection = BloomBlockingStore.loadSelection(), BloomBlockingStore.hasTargets(selection) else {
        throw BlockingControlError.noTargets
      }
      BloomBlockingStore.apply(selection)
      BloomBlockingStore.defaults?.set(true, forKey: BloomBlockingStore.activeKey)
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
      try BloomBlockingStore.startUsage(session: session, user: user, budget: Int64(budget),
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

    AsyncFunction("startCreditAccess") { (durationMillis: Double, requestElapsedMillis: Double, requestBoot: Int) throws -> Void in
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
      try BloomBlockingStore.startCountdown(seconds: remaining / 1000, selection: selection)
      #else
      throw BlockingControlError.unavailable
      #endif
    }

    AsyncFunction("endCreditAccess") { () -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      BloomBlockingStore.endCountdown()
      #endif
    }

    AsyncFunction("stopBlocking") { () throws -> Void in
      #if canImport(FamilyControls) && canImport(ManagedSettings)
      guard BloomBlockingStore.countdownRemaining() <= 0 else { throw BlockingControlError.sessionActive }
      guard try !BloomBlockingStore.usageExists() else { throw BlockingControlError.usageNeedsSync }
      BloomBlockingStore.clearShields()
      BloomBlockingStore.defaults?.set(false, forKey: BloomBlockingStore.activeKey)
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

  var errorDescription: String? {
    switch self {
    case .authorizationRequired: return "Screen Time access is required to enable blocking."
    case .noTargets: return "Choose at least one app or website first."
    case .unavailable: return "Screen Time controls are unavailable on this OS version."
    case .sessionActive: return "Wait until screen time ends before changing blocking."
    case .usageNeedsSync: return "Finish and sync the screen-time session before changing blocking."
    case .appGroupUnavailable: return "Bloom's Screen Time extension is not configured for this app."
    case .invalidDuration: return "The screen-time session expired or could not be timed."
    }
  }
}

#if canImport(FamilyControls) && canImport(ManagedSettings)
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
        if wasOpen && current.closed && defaults?.bool(forKey: activeKey) == true, let selection = loadSelection() { apply(selection) }
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
      state = current
      return current
    }
    guard let closed else { return nil }
    DeviceActivityCenter().stopMonitoring([DeviceActivityName("bloom.usage.expiry.\(closed.sessionId)")])
    return closed.response
  }

  static func startUsage(session: String, user: String, budget: Int64, startedAt: Date, expiry: Date, selection: FamilyActivitySelection) throws {
    guard UUID(uuidString: session) != nil, UUID(uuidString: user) != nil, startedAt <= Date(), expiry > Date() else { throw BlockingControlError.invalidDuration }
    let center = DeviceActivityCenter()
    let expiryMonitor = DeviceActivityName("bloom.usage.expiry.\(session)")
    let calendar = Calendar.current
    let components: Set<Calendar.Component> = [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second]
    let now = Date()
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
        clearShields()
      }
    } catch {
      center.stopMonitoring([expiryMonitor])
      try? file.mutate { state in
        if var current = state, current.sessionId == session {
          current.finish(now: Date())
          state = current
        }
      }
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
    defaults.removeObject(forKey: countdownEndKey)
  }

  static func startCountdown(seconds: Double, selection: FamilyActivitySelection) throws {
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
      clearShields()
    } catch {
      defaults.removeObject(forKey: countdownEndKey)
      DeviceActivityCenter().stopMonitoring([countdownName])
      apply(selection)
      throw error
    }
  }

  static func endCountdown() {
    DeviceActivityCenter().stopMonitoring([countdownName])
    if defaults?.bool(forKey: activeKey) == true, let selection = loadSelection() { apply(selection) }
    defaults?.removeObject(forKey: countdownEndKey)
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
      FamilyActivityPicker(selection: $selection)
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
