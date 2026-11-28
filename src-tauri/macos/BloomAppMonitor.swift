import AppKit
import ApplicationServices
import Darwin
import Foundation
import os

/// Launch agent that applies selected app and website protection in the background.
@main struct BloomAppMonitor {
  private static let logger = Logger(subsystem: "com.focusflow.focusFlowFlutter", category: "monitor")

  private struct ActiveShieldContext {
    let pid: pid_t
    let target: MacAppShieldOverlay.ShieldTarget
  }

  private struct PendingWebsiteShield {
    let pid: pid_t
    let host: String
    var seenCount: Int
  }

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
    let shieldOverlay = MacAppShieldOverlay()
    var activeShield: ActiveShieldContext?
    var pendingWebsiteShield: PendingWebsiteShield?
    let monitorPID = ProcessInfo.processInfo.processIdentifier
    let usageStore = try? MacUsageStore.shared(group: group)
    try? usageStore?.recoverAfterInterruption()
    var interactive = true
    var lastHeartbeat = 0.0
    var lastProviderQuery = 0.0
    var lastBrokerPublish = 0.0
    var lastWebsitePolicySignature = ""
    var requestedAccessibilityPrompt = false

    func clearShield() {
      activeShield = nil
      shieldOverlay.dismiss()
    }

    func showShield(for runningApp: NSRunningApplication, target: MacAppShieldOverlay.ShieldTarget, balanceHint: String?) {
      activeShield = ActiveShieldContext(pid: runningApp.processIdentifier, target: target)
      shieldOverlay.show(
        target: target,
        appIcon: runningApp.icon,
        balanceHint: balanceHint,
        onOpenBloom: {
          clearShield()
          MacAppShieldOverlay.openBloomApp()
        },
        onSwitchAway: {
          clearShield()
          _ = runningApp.hide()
        }
      )
    }

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
      let balanceHint = MacDisplayBalance.formatHint(MacDisplayBalance.read(from: defaults))
      let blockUnreadableBrowser = interactive && unreadableBrowser != nil && !creditAllowed && !usageAllowed
      let blockRuleSiteInBrowser = rules.shouldBlockActiveBrowser(host: browserAddress?.host,
        interactive: interactive, protectionEnabled: websiteBlocking,
        creditAllowed: creditAllowed, usageAllowed: usageAllowed)

      if !interactive || creditAllowed || usageAllowed {
        pendingWebsiteShield = nil
        clearShield()
      } else if let app, app.processIdentifier == monitorPID {
        if let currentShield = activeShield,
           let runningShielded = workspace.runningApplications.first(where: { $0.processIdentifier == currentShield.pid && !$0.isTerminated && !$0.isHidden }) {
          switch currentShield.target {
          case .app(let bundleID, _, _):
            if appBlocking && MacAppRules.shouldBlock(bundleId: bundleID, active: true, selected: selectedApps, creditAllowed: false) {
              showShield(for: runningShielded, target: currentShield.target, balanceHint: balanceHint)
            } else {
              clearShield()
            }
          case .website(let shieldedHost, _, let browserName, _):
            let rechecked = websiteBlocking ? MacBrowserAddress.current(for: runningShielded, accessibilityAllowed: accessibilityTrusted) : nil
            let recheckedHost = rechecked?.host.flatMap { rules.blocks($0) ? $0 : nil }
            if let recheckedHost {
              let managedDomains = defaults.stringArray(forKey: "managedDomains") ?? []
              let isManaged = WebsiteRules(configuration: ["blockedDomains": managedDomains]).blocks(recheckedHost)
              let nextTarget = MacAppShieldOverlay.ShieldTarget.website(
                host: recheckedHost,
                browserBundleID: runningShielded.bundleIdentifier ?? "",
                browserName: browserName,
                isManaged: isManaged
              )
              showShield(for: runningShielded, target: nextTarget, balanceHint: balanceHint)
            } else if recheckedHost == nil && shieldedHost != "" {
              clearShield()
            } else {
              clearShield()
            }
          case .unreadableBrowser:
            let rechecked = websiteBlocking ? MacBrowserAddress.current(for: runningShielded, accessibilityAllowed: accessibilityTrusted) : nil
            if websiteBlocking, let rechecked, !rechecked.readable {
              showShield(for: runningShielded, target: currentShield.target, balanceHint: balanceHint)
            } else {
              clearShield()
            }
          }
        } else {
          clearShield()
        }
      } else if let app, appBlocking,
                MacAppRules.shouldBlock(bundleId: app.bundleIdentifier, active: true, selected: selectedApps, creditAllowed: false) {
        pendingWebsiteShield = nil
        let isManaged = (defaults.stringArray(forKey: "managedApps") ?? []).contains {
          $0.lowercased() == (app.bundleIdentifier ?? "").lowercased()
        }
        let target = MacAppShieldOverlay.ShieldTarget.app(
          bundleID: app.bundleIdentifier ?? "",
          displayName: app.localizedName ?? app.bundleIdentifier ?? "This app",
          isManaged: isManaged
        )
        showShield(for: app, target: target, balanceHint: balanceHint)
      } else if let app, blockRuleSiteInBrowser, let host = websiteHost {
        // Debounce one poll (~0.35s) so browser profiles with the Bloom extension
        // redirect to blocked.html cleanly without flashing the native overlay.
        if let existing = pendingWebsiteShield, existing.pid == app.processIdentifier, existing.host == host {
          pendingWebsiteShield = PendingWebsiteShield(pid: app.processIdentifier, host: host, seenCount: existing.seenCount + 1)
        } else {
          pendingWebsiteShield = PendingWebsiteShield(pid: app.processIdentifier, host: host, seenCount: 1)
        }
        if (pendingWebsiteShield?.seenCount ?? 0) >= 2 {
          let managedDomains = defaults.stringArray(forKey: "managedDomains") ?? []
          let isManaged = WebsiteRules(configuration: ["blockedDomains": managedDomains]).blocks(host)
          let target = MacAppShieldOverlay.ShieldTarget.website(
            host: host,
            browserBundleID: browserAddress?.bundleIdentifier ?? app.bundleIdentifier ?? "",
            browserName: browserAddress?.browserName ?? app.localizedName ?? "Browser",
            isManaged: isManaged
          )
          showShield(for: app, target: target, balanceHint: balanceHint)
        } else {
          clearShield()
        }
      } else if let app, blockUnreadableBrowser, let unreadable = unreadableBrowser {
        pendingWebsiteShield = nil
        let target = MacAppShieldOverlay.ShieldTarget.unreadableBrowser(
          browserBundleID: unreadable.bundleIdentifier,
          browserName: unreadable.browserName
        )
        showShield(for: app, target: target, balanceHint: balanceHint)
      } else {
        pendingWebsiteShield = nil
        clearShield()
      }

      _ = MacSharedPreferences.write([
        "monitorHideFailed": false,
        "monitorBrowserHideFailed": false,
      ])

      let accessDecision = creditAllowed ? "credit" : usageAllowed ? "usage" : "denied"
      let policySignature = "interactive=\(interactive ? "yes" : "no") protection=\(websiteBlocking ? "on" : "off") address=\(browserAddress?.readable == true ? "readable" : browserAddress?.source ?? "none") source=\(browserAddress?.source ?? "none") rule-match=\(websiteHost == nil ? "no" : "yes") access=\(accessDecision) active-block=\(blockRuleSiteInBrowser ? "yes" : "no")"
      let policyChanged = policySignature != lastWebsitePolicySignature
      if policyChanged {
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
      if policyChanged || now - lastBrokerPublish >= 500 {
        lastBrokerPublish = now
        MacPolicyBrokerClient.shared.publish(policySnapshot) { accepted in
          let acknowledgedAt = FilterCreditClock.nowMillis()
          let saved = MacSharedPreferences.write([
            "monitorPolicyBrokerSnapshotAccepted": accepted,
            "monitorPolicyBrokerSnapshotAckMillis": NSNumber(value: acknowledgedAt),
          ])
          if !saved { logger.error("Monitor could not publish its website-policy broker status.") }
        }
      }
    }
    let observer = workspace.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { _ in Task { @MainActor in checkFrontmost() } }
    let asleep = workspace.notificationCenter.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in Task { @MainActor in interactive = false; checkFrontmost() } }
    let awake = workspace.notificationCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in Task { @MainActor in interactive = true; checkFrontmost() } }
    let inactive = workspace.notificationCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { _ in Task { @MainActor in interactive = false; checkFrontmost() } }
    let active = workspace.notificationCenter.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { _ in Task { @MainActor in interactive = true; checkFrontmost() } }
    let timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in Task { @MainActor in checkFrontmost() } }
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
