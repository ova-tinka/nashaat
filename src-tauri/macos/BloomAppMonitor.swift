import AppKit
import ApplicationServices
import Darwin
import Foundation
import os

/// Launch agent that applies selected app and website protection in the background.
@main struct BloomAppMonitor {
  private static let logger = Logger(subsystem: "com.focusflow.focusFlowFlutter", category: "monitor")

  @MainActor static func main() {
    guard let group = BloomAppGroup.identifier else {
      logger.error("Monitor cannot resolve its signed app-group entitlement.")
      return
    }
    guard let defaults = UserDefaults(suiteName: group) else {
      logger.error("Monitor cannot open shared preferences.")
      return
    }
    logger.info("Monitor started with shared preferences available.")
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    let workspace = NSWorkspace.shared
    var enforcement = MacAppEnforcement(running: Set(workspace.runningApplications.map(\.processIdentifier)))
    var warningPanel: NSPanel?
    func showAppWarning() {
      guard warningPanel == nil else { return }
      let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 430, height: 130),
        styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
      panel.title = "Bloom app protection"
      panel.isReleasedWhenClosed = false
      panel.level = .floating
      let label = NSTextField(wrappingLabelWithString: "Selected apps will be asked to quit in 30 seconds. Save your work now. Apps that remain open may be force closed.")
      label.frame = NSRect(x: 24, y: 25, width: 382, height: 75)
      panel.contentView?.addSubview(label)
      panel.center()
      panel.orderFrontRegardless()
      warningPanel = panel
    }
    let usageStore = try? MacUsageStore.shared(group: group)
    try? usageStore?.recoverAfterInterruption()
    var interactive = true
    var lastHeartbeat = 0.0
    var lastProviderQuery = 0.0
    var lastWebsitePolicySignature = ""
    var requestedAccessibilityPrompt = false
    func checkFrontmost() {
      let now = FilterCreditClock.nowMillis()
      guard let boot = FilterCreditClock.boot() else {
        logger.error("Monitor cannot read the system boot clock.")
        return
      }
      if now - lastHeartbeat >= 5000 {
        let saved = MacSharedPreferences.write([
          "monitorBoot": NSNumber(value: boot),
          "monitorHeartbeatMillis": NSNumber(value: now),
          "monitorAccessibilityTrusted": AXIsProcessTrusted(),
          "monitorExecutablePath": NSRunningApplication.current.executableURL?.path ?? "",
        ])
        if !saved { logger.error("Monitor could not publish its shared heartbeat.") }
        lastHeartbeat = now
      }
      if now - lastProviderQuery >= 5000 {
        lastProviderQuery = now
        MacPolicyBrokerClient.shared.providerHeartbeat { atMillis, providerBoot in
          _ = MacSharedPreferences.write(["filterProviderHeartbeatMillis": NSNumber(value: atMillis),
            "filterProviderHeartbeatBoot": NSNumber(value: providerBoot)])
        }
      }
      let app = workspace.frontmostApplication
      let selectedApps = Set((defaults.stringArray(forKey: "blockedApps") ?? []) + (defaults.stringArray(forKey: "managedApps") ?? [])).sorted()
      let selectedDomains = defaults.stringArray(forKey: "blockedDomains") ?? []
      let websiteBlocking = defaults.bool(forKey: "websiteBlockingEnabled") && !selectedDomains.isEmpty
      let accessibilityTrusted = AXIsProcessTrusted()
      let browserAddress: MacBrowserAddressResult? = if interactive && websiteBlocking, let app {
        MacBrowserAddress.current(for: app, accessibilityAllowed: accessibilityTrusted)
      } else { nil }
      let rules = WebsiteRules(configuration: ["blockedDomains": selectedDomains])
      let websiteHost = browserAddress?.host.flatMap { rules.blocks($0) ? $0 : nil }
      let unreadableBrowser = browserAddress.flatMap { $0.readable ? nil : $0 }
      let appBlocking = defaults.bool(forKey: "appBlockingEnabled")
      let shouldRequestAccessibility = !accessibilityTrusted
        && (appBlocking && !selectedApps.isEmpty || (websiteBlocking && unreadableBrowser != nil))
      if shouldRequestAccessibility && !requestedAccessibilityPrompt {
        requestedAccessibilityPrompt = true
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
      }
      let appTarget = appBlocking
        && MacAppRules.shouldBlock(bundleId: app?.bundleIdentifier, active: true, selected: selectedApps, creditAllowed: false)
      let selectedTarget = interactive && (appTarget || (websiteBlocking && MacMonitorRules.shouldCountWebsiteUse(eligibleBlockedHost: websiteHost)))
      let config: [String: Any] = [
        "creditBoot": defaults.object(forKey: "creditBoot") ?? NSNull(),
        "creditDeadlineMillis": defaults.object(forKey: "creditDeadlineMillis") ?? NSNull(),
      ]
      let usage = try? usageStore?.observe(active: selectedTarget)
      let usageAllowed = usage.map { $0.allows(now: now, boot: boot) } ?? false
      let websiteUsageTarget = usageAllowed && usage?.activeSinceMillis != nil && websiteBlocking ? websiteHost : nil
      let websiteUsageBrowser = usageAllowed && usage?.activeSinceMillis != nil && websiteBlocking ? unreadableBrowser?.bundleIdentifier : nil
      let creditAllowed = FilterCreditClock.isAllowed(configuration: config)
      let runningApps = workspace.runningApplications.filter { !$0.isTerminated }
      let runningIDs = Set(runningApps.map(\.processIdentifier))
      let blockedIDs = Set(runningApps.filter { candidate in
        MacAppRules.shouldBlock(bundleId: candidate.bundleIdentifier, active: appBlocking,
          selected: selectedApps, creditAllowed: creditAllowed || usageAllowed)
      }.map(\.processIdentifier))
      if !interactive { enforcement.restartWarnings(now: now) }
      let actions = enforcement.update(running: runningIDs, blocked: blockedIDs, now: now)
      for action in actions {
        switch action {
        case .warn: showAppWarning()
        case .quit(let pid): _ = runningApps.first { $0.processIdentifier == pid }?.terminate()
        case .forceQuit(let pid): _ = runningApps.first { $0.processIdentifier == pid }?.forceTerminate()
        }
      }
      if !enforcement.hasWarnings { warningPanel?.close(); warningPanel = nil }
      // A successful quit request is not proof the app exited. Keep the
      // protection status degraded until every selected process is gone.
      _ = MacSharedPreferences.write(["monitorHideFailed": enforcement.hasUnconfirmedApps])
      let blockUnreadableBrowser = interactive && unreadableBrowser != nil && !creditAllowed && !usageAllowed
      let blockRuleSiteInBrowser = rules.shouldBlockActiveBrowser(host: browserAddress?.host,
        interactive: interactive, protectionEnabled: websiteBlocking,
        creditAllowed: creditAllowed, usageAllowed: usageAllowed)
      let accessDecision = creditAllowed ? "credit" : usageAllowed ? "usage" : "denied"
      let policySignature = "interactive=\(interactive ? "yes" : "no") protection=\(websiteBlocking ? "on" : "off") address=\(browserAddress?.readable == true ? "readable" : browserAddress?.source ?? "none") source=\(browserAddress?.source ?? "none") rule-match=\(websiteHost == nil ? "no" : "yes") access=\(accessDecision) active-block=\(blockRuleSiteInBrowser ? "yes" : "no")"
      if policySignature != lastWebsitePolicySignature {
        logger.debug("website-policy \(policySignature, privacy: .public)")
        lastWebsitePolicySignature = policySignature
      }
      var statusUpdates: [String: Any] = [
        "usageTargetDomain": websiteUsageTarget ?? "",
        "usageTargetBrowser": websiteUsageBrowser ?? "",
        "blockedUnreadableBrowserBundleId": websiteBlocking ? unreadableBrowser?.bundleIdentifier ?? "" : "",
        "blockedActiveBrowserBundleId": blockRuleSiteInBrowser ? browserAddress?.bundleIdentifier ?? "" : "",
        "blockedActiveBrowserCheckedAtMillis": NSNumber(value: now),
        "blockedActiveBrowserBoot": NSNumber(value: boot),
        "usageTargetHeartbeatMillis": NSNumber(value: now),
        "usageTargetBoot": NSNumber(value: boot),
      ]
      if let browserAddress {
        statusUpdates["monitorBrowserBundleId"] = browserAddress.bundleIdentifier
        statusUpdates["monitorBrowserName"] = browserAddress.browserName
        statusUpdates["monitorBrowserAddressStatus"] = browserAddress.readable ? "readable" : browserAddress.source
        statusUpdates["monitorBrowserAutomationStatus"] = browserAddress.automationStatus
        statusUpdates["monitorBrowserCheckedAtMillis"] = NSNumber(value: now)
      }
      _ = MacSharedPreferences.write(statusUpdates)
      let usageDeadline = usage.flatMap { state -> Double? in
        guard usageAllowed, state.activeSinceMillis != nil, let started = state.startedElapsedMillis else { return nil }
        return min(state.expiryElapsedMillis, started + Double(state.budgetMillis))
      } ?? 0
      let policySnapshot = MacPolicyBrokerSnapshot(
        userID: UInt32(getuid()),
        publishedAtMillis: now,
        websiteBlockingEnabled: websiteBlocking,
        browserAddressStatus: browserAddress?.readable == true ? "readable" : browserAddress?.source ?? "inactive",
        unreadableBrowserBundleIdentifier: unreadableBrowser?.bundleIdentifier ?? "",
        activeBlockedBrowserBundleIdentifier: blockRuleSiteInBrowser ? browserAddress?.bundleIdentifier ?? "" : "",
        activeBlockedBrowserCheckedAtMillis: now,
        activeBlockedBrowserBoot: boot,
        monitorHeartbeatMillis: now,
        monitorBoot: boot,
        usageTargetDomain: websiteUsageTarget ?? "",
        usageTargetBrowser: websiteUsageBrowser ?? "",
        usageTargetHeartbeatMillis: now,
        usageTargetBoot: boot,
        usageAccessDeadlineMillis: usageDeadline)
      MacPolicyBrokerClient.shared.publish(policySnapshot) { accepted in
        let acknowledgedAt = FilterCreditClock.nowMillis()
        let saved = MacSharedPreferences.write([
          "monitorPolicyBrokerSnapshotAccepted": accepted,
          "monitorPolicyBrokerSnapshotAckMillis": NSNumber(value: acknowledgedAt),
        ])
        if !saved { logger.error("Monitor could not publish its website-policy broker status.") }
      }
      if blockUnreadableBrowser || blockRuleSiteInBrowser {
        let hideAccepted = app?.hide() ?? false
        if !hideAccepted {
          var failures: [String: Any] = [:]
          if blockUnreadableBrowser || blockRuleSiteInBrowser { failures["monitorBrowserHideFailed"] = true }
          if !failures.isEmpty { _ = MacSharedPreferences.write(failures) }
        } else if let app {
          // `hide()` reports that the request was accepted. Verify the state
          // after AppKit has had a run-loop turn, and clear a previous latched
          // failure only after observing the app hidden (or terminated).
          DispatchQueue.main.async {
            let hidden = MacMonitorRules.didHideSuccessfully(callAccepted: hideAccepted, isHidden: app.isHidden, isTerminated: app.isTerminated)
            var updates: [String: Any] = [:]
            if blockUnreadableBrowser || blockRuleSiteInBrowser { updates["monitorBrowserHideFailed"] = !hidden }
            if !updates.isEmpty { _ = MacSharedPreferences.write(updates) }
          }
        }
      } else { _ = MacSharedPreferences.write(["monitorBrowserHideFailed": false]) }
    }
    let observer = workspace.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { _ in Task { @MainActor in checkFrontmost() } }
    let asleep = workspace.notificationCenter.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in Task { @MainActor in interactive = false; checkFrontmost() } }
    let awake = workspace.notificationCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in Task { @MainActor in interactive = true; enforcement.restartWarnings(now: FilterCreditClock.nowMillis()); checkFrontmost() } }
    let inactive = workspace.notificationCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { _ in Task { @MainActor in interactive = false; checkFrontmost() } }
    let active = workspace.notificationCenter.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { _ in Task { @MainActor in interactive = true; enforcement.restartWarnings(now: FilterCreditClock.nowMillis()); checkFrontmost() } }
    let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in Task { @MainActor in checkFrontmost() } }
    checkFrontmost()
    application.run()
    timer.invalidate()
    workspace.notificationCenter.removeObserver(observer)
    workspace.notificationCenter.removeObserver(asleep)
    workspace.notificationCenter.removeObserver(awake)
    workspace.notificationCenter.removeObserver(inactive)
    workspace.notificationCenter.removeObserver(active)
  }
}
