import Foundation

@main struct MacPolicyBrokerCheck {
  static func main() throws {
    let uid: UInt32 = 501
    let now = 10_000.0
    let boot: Int64 = 77
    let configuration: [String: Any] = ["blockedDomains": ["example.com"]]

    func makeSnapshot(userID: UInt32 = uid, enabled: Bool = true,
                      addressStatus: String = "readable",
                      blockedBrowser: String = "com.apple.Safari",
                      checkedAt: Double = now,
                      checkedBoot: Int64 = boot,
                      targetDomain: String = "example.com",
                      targetBrowser: String = "",
                      usageHeartbeat: Double = now,
                      accessDeadline: Double = now + 5_000,
                      publishedAt: Double = now) -> MacPolicyBrokerSnapshot {
      MacPolicyBrokerSnapshot(userID: userID, publishedAtMillis: publishedAt,
        websiteBlockingEnabled: enabled, browserAddressStatus: addressStatus,
        unreadableBrowserBundleIdentifier: addressStatus == "unreadable" ? blockedBrowser : "",
        activeBlockedBrowserBundleIdentifier: blockedBrowser,
        activeBlockedBrowserCheckedAtMillis: checkedAt, activeBlockedBrowserBoot: checkedBoot,
        monitorHeartbeatMillis: now, monitorBoot: boot,
        usageTargetDomain: targetDomain, usageTargetBrowser: targetBrowser,
        usageTargetHeartbeatMillis: usageHeartbeat, usageTargetBoot: boot,
        usageAccessDeadlineMillis: accessDeadline)
    }

    let snapshot = makeSnapshot()
    precondition(snapshot.isValid(for: uid, nowMillis: now))
    precondition(MacPolicyBrokerCachePolicy.canReuseForForegroundEnforcement(
      snapshot: snapshot, userID: uid, fetchedAtMillis: now, nowMillis: now + 100, boot: boot))
    precondition(!MacPolicyBrokerCachePolicy.canReuseForForegroundEnforcement(
      snapshot: snapshot, userID: uid, fetchedAtMillis: now,
      nowMillis: now + MacPolicyBrokerSnapshot.maximumActiveBrowserAgeMillis + 1, boot: boot))
    precondition(!MacPolicyBrokerCachePolicy.canReuseForForegroundEnforcement(
      snapshot: snapshot, userID: uid + 1, fetchedAtMillis: now, nowMillis: now + 100, boot: boot))
    precondition(!MacPolicyBrokerCachePolicy.canReuseForForegroundEnforcement(
      snapshot: snapshot, userID: uid, fetchedAtMillis: now, nowMillis: now + 100, boot: boot + 1))
    precondition(!MacPolicyBrokerCachePolicy.canReuseForForegroundEnforcement(
      snapshot: makeSnapshot(enabled: false), userID: uid, fetchedAtMillis: now,
      nowMillis: now + 100, boot: boot))
    precondition(snapshot.freshMonitor(nowMillis: now + 100, boot: boot))
    precondition(!snapshot.freshMonitor(nowMillis: now + 100, boot: boot + 1))
    precondition(!snapshot.isValid(for: uid + 1, nowMillis: now))
    precondition(MacPolicyBrokerIdentity.signingInformationFlags.rawValue & kSecCSSigningInformation != 0)

    precondition(MacPolicyBrokerAccessPolicy.mayConnect(peerIdentifier: MacPolicyBrokerAccessPolicy.monitorIdentifier,
      peerTeam: "TEAM123456", expectedTeam: "TEAM123456"))
    precondition(MacPolicyBrokerAccessPolicy.mayConnect(peerIdentifier: MacPolicyBrokerAccessPolicy.hostIdentifier,
      peerTeam: "TEAM123456", expectedTeam: "TEAM123456"))
    precondition(!MacPolicyBrokerAccessPolicy.mayConnect(peerIdentifier: MacPolicyBrokerAccessPolicy.hostIdentifier,
      peerTeam: "OTHER12345", expectedTeam: "TEAM123456"))
    precondition(!MacPolicyBrokerAccessPolicy.mayConnect(peerIdentifier: MacPolicyBrokerAccessPolicy.filterIdentifier,
      peerTeam: "OTHER12345", expectedTeam: "TEAM123456"))
    precondition(!MacPolicyBrokerAccessPolicy.mayConnect(peerIdentifier: "untrusted.helper",
      peerTeam: "TEAM123456", expectedTeam: "TEAM123456"))
    let requirement = MacPolicyBrokerAccessPolicy.connectionRequirement(peerIdentifier: MacPolicyBrokerAccessPolicy.hostIdentifier, expectedTeam: "TEAM123456")
    precondition(requirement?.contains("identifier \"com.focusflow.focusFlowFlutter\"") == true)
    precondition(MacPolicyBrokerAccessPolicy.connectionRequirement(peerIdentifier: "untrusted.helper", expectedTeam: "TEAM123456") == nil)
    precondition(MacPolicyBrokerAccessPolicy.connectionRequirement(peerIdentifier: MacPolicyBrokerAccessPolicy.hostIdentifier, expectedTeam: "BAD\"TEAM") == nil)
    precondition(MacPolicyBrokerAccessPolicy.mayPublish(peerIdentifier: MacPolicyBrokerAccessPolicy.monitorIdentifier,
      peerUID: uid, claimedUID: uid, snapshotUID: uid))
    precondition(!MacPolicyBrokerAccessPolicy.mayPublish(peerIdentifier: MacPolicyBrokerAccessPolicy.monitorIdentifier,
      peerUID: 0, claimedUID: 0, snapshotUID: 0))
    precondition(!MacPolicyBrokerAccessPolicy.mayPublish(peerIdentifier: "untrusted.helper",
      peerUID: uid, claimedUID: uid, snapshotUID: uid))
    precondition(!MacPolicyBrokerAccessPolicy.mayPublish(peerIdentifier: MacPolicyBrokerAccessPolicy.monitorIdentifier,
      peerUID: uid, claimedUID: uid + 1, snapshotUID: uid))
    precondition(MacPolicyBrokerAccessPolicy.mayRead(peerIdentifier: MacPolicyBrokerAccessPolicy.filterIdentifier, peerUID: 0))
    precondition(!MacPolicyBrokerAccessPolicy.mayRead(peerIdentifier: MacPolicyBrokerAccessPolicy.filterIdentifier, peerUID: uid))
    precondition(!MacPolicyBrokerAccessPolicy.mayRead(peerIdentifier: "untrusted.helper", peerUID: 0))

    precondition(snapshot.shouldDropHostlessFlow(sourceBundleIdentifier: "com.apple.Safari",
      nowMillis: now + 100, boot: boot))
    precondition(!snapshot.shouldDropHostlessFlow(sourceBundleIdentifier: "com.brave.Browser",
      nowMillis: now + 100, boot: boot))
    precondition(!snapshot.shouldDropHostlessFlow(sourceBundleIdentifier: nil,
      nowMillis: now + 100, boot: boot))
    precondition(!makeSnapshot(checkedAt: now - MacPolicyBrokerSnapshot.maximumActiveBrowserAgeMillis - 1)
      .shouldDropHostlessFlow(sourceBundleIdentifier: "com.apple.Safari", nowMillis: now, boot: boot))
    precondition(!snapshot.shouldDropHostlessFlow(sourceBundleIdentifier: "com.apple.Safari",
      nowMillis: now + 100, boot: boot + 1))
    precondition(!makeSnapshot(checkedBoot: boot + 1).shouldDropHostlessFlow(sourceBundleIdentifier: "com.apple.Safari",
      nowMillis: now, boot: boot))
    precondition(!makeSnapshot(enabled: false).shouldDropHostlessFlow(sourceBundleIdentifier: "com.apple.Safari",
      nowMillis: now + 100, boot: boot))

    let braveSnapshot = makeSnapshot(blockedBrowser: "com.brave.Browser")
    precondition(braveSnapshot.shouldDropHostlessFlow(sourceBundleIdentifier: "com.brave.Browser",
      nowMillis: now + 100, boot: boot))
    precondition(braveSnapshot.shouldDropHostlessFlow(sourceBundleIdentifier: "com.brave.Browser.helper.renderer",
      nowMillis: now + 100, boot: boot))
    precondition(!braveSnapshot.shouldDropHostlessFlow(sourceBundleIdentifier: "com.brave.Browser.helper.utility",
      nowMillis: now + 100, boot: boot))

    let unreadable = makeSnapshot(addressStatus: "unreadable")
    precondition(unreadable.unreadableBrowserIdentifier(nowMillis: now + 100, boot: boot) == "com.apple.Safari")
    precondition(unreadable.unreadableBrowserIdentifier(nowMillis: now + 100, boot: boot + 1) == nil)
    precondition(makeSnapshot(addressStatus: "unsupported").unreadableBrowserIdentifier(nowMillis: now, boot: boot) == nil)

    precondition(snapshot.allowsWebsiteUsage(host: "www.example.com", browserIdentifier: nil,
      nowMillis: now + 100, boot: boot, configuration: configuration))
    precondition(!snapshot.allowsWebsiteUsage(host: "example.org", browserIdentifier: nil,
      nowMillis: now + 100, boot: boot, configuration: configuration))
    precondition(!makeSnapshot(targetBrowser: "com.apple.Safari").allowsWebsiteUsage(host: "example.com",
      browserIdentifier: "com.brave.Browser", nowMillis: now + 100, boot: boot, configuration: configuration))
    precondition(!makeSnapshot(accessDeadline: now).allowsWebsiteUsage(host: "example.com", browserIdentifier: nil,
      nowMillis: now + 100, boot: boot, configuration: configuration))
    precondition(makeSnapshot(targetBrowser: "com.google.Chrome").allowsUnknownBrowserUsage(
      bundleIdentifier: "com.google.Chrome", nowMillis: now + 100, boot: boot, configuration: configuration))
    precondition(!snapshot.allowsUnknownBrowserUsage(bundleIdentifier: "com.google.Chrome",
      nowMillis: now + 100, boot: boot, configuration: configuration))

    let store = MacPolicyBrokerStore()
    precondition(MacPolicyBrokerAccessPolicy.mayRequestHostsCleanup(peerIdentifier: MacPolicyBrokerAccessPolicy.hostIdentifier, peerUID: uid))
    precondition(!MacPolicyBrokerAccessPolicy.mayRequestHostsCleanup(peerIdentifier: MacPolicyBrokerAccessPolicy.hostIdentifier, peerUID: 0))
    precondition(!MacPolicyBrokerAccessPolicy.mayRequestHostsCleanup(peerIdentifier: MacPolicyBrokerAccessPolicy.monitorIdentifier, peerUID: uid))
    precondition(!MacPolicyBrokerAccessPolicy.mayRequestHostsCleanup(peerIdentifier: MacPolicyBrokerAccessPolicy.filterIdentifier, peerUID: 0))
    let encoded = try JSONEncoder().encode(snapshot)
    precondition(store.publish(encoded, peerIdentifier: MacPolicyBrokerAccessPolicy.monitorIdentifier,
      peerUID: uid, claimedUID: uid, nowMillis: now))
    let rootRead = store.snapshot(for: uid, peerIdentifier: MacPolicyBrokerAccessPolicy.filterIdentifier,
      peerUID: 0, nowMillis: now)
    precondition(rootRead.flatMap { try? JSONDecoder().decode(MacPolicyBrokerSnapshot.self, from: $0) } == snapshot)
    precondition(store.snapshot(for: uid + 1, peerIdentifier: MacPolicyBrokerAccessPolicy.filterIdentifier,
      peerUID: 0, nowMillis: now) == nil)
    precondition(store.snapshot(for: uid, peerIdentifier: MacPolicyBrokerAccessPolicy.filterIdentifier,
      peerUID: uid, nowMillis: now) == nil)
    precondition(store.snapshot(for: uid, peerIdentifier: "untrusted.helper", peerUID: 0, nowMillis: now) == nil)
    precondition(store.snapshot(for: uid, peerIdentifier: MacPolicyBrokerAccessPolicy.filterIdentifier,
      peerUID: 0, nowMillis: now + MacPolicyBrokerSnapshot.maximumHeartbeatAgeMillis + 1) == nil)
    precondition(!store.publish(encoded, peerIdentifier: MacPolicyBrokerAccessPolicy.monitorIdentifier,
      peerUID: uid, claimedUID: uid + 1, nowMillis: now))

    precondition(!store.recordProviderHeartbeat(peerIdentifier: MacPolicyBrokerAccessPolicy.monitorIdentifier,
      peerUID: uid, nowMillis: now, boot: boot))
    precondition(!store.recordProviderHeartbeat(peerIdentifier: MacPolicyBrokerAccessPolicy.filterIdentifier,
      peerUID: uid, nowMillis: now, boot: boot))
    precondition(!store.recordProviderHeartbeat(peerIdentifier: MacPolicyBrokerAccessPolicy.filterIdentifier,
      peerUID: 0, nowMillis: .nan, boot: boot))
    precondition(!store.recordProviderHeartbeat(peerIdentifier: MacPolicyBrokerAccessPolicy.filterIdentifier,
      peerUID: 0, nowMillis: now, boot: nil))
    precondition(store.recordProviderHeartbeat(peerIdentifier: MacPolicyBrokerAccessPolicy.filterIdentifier,
      peerUID: 0, nowMillis: now, boot: boot))
    precondition(store.providerHeartbeat(peerIdentifier: MacPolicyBrokerAccessPolicy.monitorIdentifier,
      peerUID: uid, nowMillis: now + 1, boot: boot)?.atMillis == now)
    precondition(store.providerHeartbeat(peerIdentifier: "untrusted.helper", peerUID: uid, nowMillis: now, boot: boot) == nil)
    precondition(store.providerHeartbeat(peerIdentifier: MacPolicyBrokerAccessPolicy.monitorIdentifier,
      peerUID: 0, nowMillis: now, boot: boot) == nil)
    precondition(store.providerHeartbeat(peerIdentifier: MacPolicyBrokerAccessPolicy.monitorIdentifier,
      peerUID: uid, nowMillis: now + 15_001, boot: boot) == nil)
    precondition(store.providerHeartbeat(peerIdentifier: MacPolicyBrokerAccessPolicy.monitorIdentifier,
      peerUID: uid, nowMillis: now, boot: boot + 1) == nil)
    precondition(store.providerHeartbeat(peerIdentifier: MacPolicyBrokerAccessPolicy.monitorIdentifier,
      peerUID: uid, nowMillis: now - 1, boot: boot) == nil)

    print("macOS policy broker checks passed")
  }
}
