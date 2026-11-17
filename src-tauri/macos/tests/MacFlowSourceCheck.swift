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
    print("macOS flow source checks passed")
  }
}
