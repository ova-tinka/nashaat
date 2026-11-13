import Foundation

struct MacAppRules {
  static let ownBundle = "com.focusflow.focusFlowFlutter"
  static let protectedBundleIds: Set<String> = [
    "com.apple.finder",
    "com.apple.dock",
    "com.apple.systempreferences",
    "com.apple.activitymonitor",
    "com.apple.terminal",
    "com.apple.loginwindow",
  ]

  static func monitorMatches(reportedPath: String?, expectedPath: String) -> Bool {
    guard let reportedPath, !reportedPath.isEmpty else { return false }
    return URL(fileURLWithPath: reportedPath).standardizedFileURL.resolvingSymlinksInPath().path
      == URL(fileURLWithPath: expectedPath).standardizedFileURL.resolvingSymlinksInPath().path
  }

  static func normalize(_ values: [String]) -> [String]? {
    guard values.count <= 500 else { return nil }
    var result = Set<String>()
    for item in values {
      let value = item.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      guard value.count > 0, value.count <= 255, value != ownBundle.lowercased(),
            !protectedBundleIds.contains(value),
            value.range(of: "^[a-z0-9][a-z0-9._-]*$", options: .regularExpression) != nil else { return nil }
      result.insert(value)
    }
    return result.sorted()
  }

  static func shouldBlock(bundleId: String?, active: Bool, selected: [String], creditAllowed: Bool) -> Bool {
    guard active, !creditAllowed, let bundleId else { return false }
    let normalized = bundleId.lowercased()
    guard normalized != ownBundle.lowercased(), !protectedBundleIds.contains(normalized) else { return false }
    return selected.contains(normalized)
  }
}
