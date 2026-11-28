import Foundation

@main struct MacFlowSourceCheck {
  static func main() {
    precondition(MacFlowSource.bundleIdentifier(for: nil) == nil)
    precondition(MacFlowSource.bundleIdentifier(for: Data([1, 2, 3])) == nil)
    precondition(MacFlowSource.unreadableBrowserDecision(sourceBundleIdentifier: nil, browserBundleIdentifier: "org.example.browser") == .continueNormalFiltering)
    precondition(MacFlowSource.unreadableBrowserDecision(sourceBundleIdentifier: "", browserBundleIdentifier: "org.example.browser") == .continueNormalFiltering)
    precondition(MacFlowSource.unreadableBrowserDecision(sourceBundleIdentifier: "org.example.browser", browserBundleIdentifier: "org.example.browser") == .inspectBrowser)
    precondition(MacFlowSource.unreadableBrowserDecision(sourceBundleIdentifier: "com.brave.Browser.helper", browserBundleIdentifier: "com.brave.Browser") == .inspectBrowser)
    precondition(MacFlowSource.unreadableBrowserDecision(sourceBundleIdentifier: "com.brave.Browser.helper.renderer", browserBundleIdentifier: "com.brave.Browser") == .inspectBrowser)
    precondition(MacFlowSource.unreadableBrowserDecision(sourceBundleIdentifier: "com.brave.Browser.framework.AlertNotificationService", browserBundleIdentifier: "com.brave.Browser") == .continueNormalFiltering)
    precondition(MacFlowSource.unreadableBrowserDecision(sourceBundleIdentifier: "org.example.other", browserBundleIdentifier: "org.example.browser") == .continueNormalFiltering)
    // An unidentified source must still reach ordinary hostname rules. It must
    // neither bypass a selected site nor cause an unrelated host to be denied.
    let decision = MacFlowSource.unreadableBrowserDecision(sourceBundleIdentifier: nil, browserBundleIdentifier: "org.example.browser")
    let rules = WebsiteRules(configuration: ["blockedDomains": ["example.com"]])
    precondition(decision == .continueNormalFiltering && rules.blocks("example.com"))
    precondition(decision == .continueNormalFiltering && !rules.blocks("example.org"))

    precondition(MacFlowSource.shouldDropHostlessFlow(sourceBundleIdentifier: "org.example.browser",
      blockedBrowserBundleIdentifier: "org.example.browser", checkedAtMillis: 1000,
      checkedBoot: 7, nowMillis: 2000, boot: 7))
    precondition(MacFlowSource.shouldDropHostlessFlow(sourceBundleIdentifier: "com.brave.Browser.helper.renderer",
      blockedBrowserBundleIdentifier: "com.brave.Browser", checkedAtMillis: 1000,
      checkedBoot: 7, nowMillis: 2000, boot: 7))
    precondition(!MacFlowSource.shouldDropHostlessFlow(sourceBundleIdentifier: "org.example.other",
      blockedBrowserBundleIdentifier: "org.example.browser", checkedAtMillis: 1000,
      checkedBoot: 7, nowMillis: 2000, boot: 7))
    precondition(!MacFlowSource.shouldDropHostlessFlow(sourceBundleIdentifier: nil,
      blockedBrowserBundleIdentifier: "org.example.browser", checkedAtMillis: 1000,
      checkedBoot: 7, nowMillis: 2000, boot: 7))
    precondition(!MacFlowSource.shouldDropHostlessFlow(sourceBundleIdentifier: "org.example.browser",
      blockedBrowserBundleIdentifier: "org.example.browser", checkedAtMillis: 1000,
      checkedBoot: 7, nowMillis: 3501, boot: 7))
    precondition(!MacFlowSource.shouldDropHostlessFlow(sourceBundleIdentifier: "org.example.browser",
      blockedBrowserBundleIdentifier: "org.example.browser", checkedAtMillis: 1000,
      checkedBoot: 8, nowMillis: 2000, boot: 7))

    for (browser, helper) in [
      ("com.google.Chrome", "com.google.Chrome.helper"),
      ("com.google.Chrome", "com.google.Chrome.helper.renderer"),
      ("com.google.Chrome.beta", "com.google.Chrome.beta.helper"),
      ("com.microsoft.edgemac", "com.microsoft.edgemac.helper.renderer"),
      ("company.thebrowser.Browser", "company.thebrowser.Browser.helper"),
      ("com.operasoftware.Opera", "com.operasoftware.Opera.helper"),
      ("org.mozilla.firefox", "org.mozilla.plugincontainer"),
    ] {
      precondition(MacFlowSource.unreadableBrowserDecision(sourceBundleIdentifier: helper, browserBundleIdentifier: browser) == .inspectBrowser)
      precondition(MacFlowSource.shouldDropHostlessFlow(sourceBundleIdentifier: helper,
        blockedBrowserBundleIdentifier: browser, checkedAtMillis: 1000,
        checkedBoot: 7, nowMillis: 2000, boot: 7))
    }

    for process in ["com.apple.Safari", "com.brave.Browser", "com.brave.Browser.helper", "com.google.Chrome", "com.google.Chrome.helper", "org.mozilla.firefox"] {
      precondition(MacFlowSource.isKnownBrowserProcess(process))
      precondition(MacFlowSource.shouldDropBrowserQUIC(isDatagram: true, remotePort: "443", sourceBundleIdentifier: process))
      precondition(!MacFlowSource.shouldDropBrowserQUIC(isDatagram: false, remotePort: "443", sourceBundleIdentifier: process))
      precondition(!MacFlowSource.shouldDropBrowserQUIC(isDatagram: true, remotePort: "53", sourceBundleIdentifier: process))
      precondition(!MacFlowSource.shouldDropBrowserQUIC(isDatagram: true, remotePort: "80", sourceBundleIdentifier: process))
      precondition(!MacFlowSource.shouldDropBrowserQUIC(isDatagram: true, remotePort: nil, sourceBundleIdentifier: process))
      precondition(!MacFlowSource.shouldDropBrowserQUIC(isDatagram: true, remotePort: "3478", sourceBundleIdentifier: process))
    }
    for nonBrowser in [nil, "", "org.example.other", "com.brave.Browser.framework.AlertNotificationService", "com.brave.Browser.helper.utility"] {
      precondition(!MacFlowSource.isKnownBrowserProcess(nonBrowser))
      precondition(!MacFlowSource.shouldDropBrowserQUIC(isDatagram: true, remotePort: "443", sourceBundleIdentifier: nonBrowser))
    }
    print("macOS flow source checks passed")
  }
}
