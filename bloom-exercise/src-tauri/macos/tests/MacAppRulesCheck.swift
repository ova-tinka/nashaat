import Foundation

@main struct MacAppRulesCheck {
  static func main() {
    precondition(MacAppRules.monitorMatches(reportedPath: "/Applications/Bloom.app/Contents/MacOS/BloomAppMonitor", expectedPath: "/Applications/Bloom.app/Contents/MacOS/BloomAppMonitor"))
    precondition(!MacAppRules.monitorMatches(reportedPath: "/Applications/Old.app/Contents/MacOS/BloomAppMonitor", expectedPath: "/Applications/Bloom.app/Contents/MacOS/BloomAppMonitor"))
    precondition(!MacAppRules.monitorMatches(reportedPath: nil, expectedPath: "/Applications/Bloom.app/Contents/MacOS/BloomAppMonitor"))
    precondition(MacAppRules.normalize([" COM.Example.App ", "com.example.app"]) == ["com.example.app"])
    precondition(MacAppRules.normalize(["com.focusflow.focusFlowFlutter"]) == nil)
    precondition(MacAppRules.normalize(["not a bundle id"]) == nil)
    precondition(MacAppRules.protectedBundleIds.allSatisfy { MacAppRules.normalize([$0]) == nil })
    precondition(MacAppRules.shouldBlock(bundleId: "com.example.App", active: true, selected: ["com.example.app"], creditAllowed: false))
    precondition(!MacAppRules.shouldBlock(bundleId: "com.apple.finder", active: true, selected: ["com.apple.finder"], creditAllowed: false))
    precondition(!MacAppRules.shouldBlock(bundleId: MacAppRules.ownBundle, active: true, selected: [MacAppRules.ownBundle.lowercased()], creditAllowed: false))
    precondition(!MacAppRules.shouldBlock(bundleId: "com.example.App", active: true, selected: ["com.example.app"], creditAllowed: true))
    print("macOS app rule checks passed")
  }
}
