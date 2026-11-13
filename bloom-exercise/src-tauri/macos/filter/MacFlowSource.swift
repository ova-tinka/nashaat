import Foundation
import Security

/// Resolves a macOS Network Extension flow's source audit token to its signing identifier.
/// Missing or invalid tokens stay unknown; callers must not treat them as a browser match.
enum MacFlowSource {
  private static let blockedBrowserFreshnessMillis = 2_500.0
  private static let browserHelperIdentifiers: [String: Set<String>] = [
    "com.brave.Browser": [
      "com.brave.Browser.helper",
      "com.brave.Browser.helper.renderer",
    ],
  ]

  static func matchesBrowserProcess(sourceBundleIdentifier: String?, browserBundleIdentifier: String) -> Bool {
    guard let sourceBundleIdentifier, !sourceBundleIdentifier.isEmpty else { return false }
    return sourceBundleIdentifier == browserBundleIdentifier
      || browserHelperIdentifiers[browserBundleIdentifier]?.contains(sourceBundleIdentifier) == true
  }

  enum UnreadableBrowserDecision: Equatable {
    case inspectBrowser
    case continueNormalFiltering
  }

  static func unreadableBrowserDecision(sourceBundleIdentifier: String?, browserBundleIdentifier: String) -> UnreadableBrowserDecision {
    matchesBrowserProcess(sourceBundleIdentifier: sourceBundleIdentifier, browserBundleIdentifier: browserBundleIdentifier)
      ? .inspectBrowser : .continueNormalFiltering
  }

  /// Applies the monitor's short-lived decision only to hostname-less flows
  /// from the same browser. Callers must leave flows with a known hostname to
  /// ordinary domain matching.
  static func shouldDropHostlessFlow(sourceBundleIdentifier: String?, blockedBrowserBundleIdentifier: String?,
                                     checkedAtMillis: Double?, checkedBoot: Int64?,
                                     nowMillis: Double, boot: Int64?) -> Bool {
    guard let blockedBrowserBundleIdentifier, !blockedBrowserBundleIdentifier.isEmpty,
          matchesBrowserProcess(sourceBundleIdentifier: sourceBundleIdentifier, browserBundleIdentifier: blockedBrowserBundleIdentifier),
          let checkedAtMillis, checkedAtMillis.isFinite,
          nowMillis.isFinite, nowMillis >= checkedAtMillis,
          nowMillis - checkedAtMillis <= blockedBrowserFreshnessMillis,
          let boot, boot > 0, checkedBoot == boot else { return false }
    return true
  }

  static func bundleIdentifier(for auditTokenData: Data?) -> String? {
    guard let auditTokenData, auditTokenData.count == MemoryLayout<audit_token_t>.size else { return nil }
    var token = audit_token_t()
    let copied = withUnsafeMutableBytes(of: &token) { destination -> Bool in
      guard destination.count == auditTokenData.count else { return false }
      auditTokenData.copyBytes(to: destination)
      return true
    }
    guard copied,
          let task = SecTaskCreateWithAuditToken(kCFAllocatorDefault, token),
          let signingIdentifier = SecTaskCopySigningIdentifier(task, nil) as String?,
          !signingIdentifier.isEmpty else { return nil }
    return signingIdentifier
  }

  static func userID(for auditTokenData: Data?) -> UInt32? {
    guard let auditTokenData, auditTokenData.count == MemoryLayout<audit_token_t>.size else { return nil }
    var token = audit_token_t()
    let copied = withUnsafeMutableBytes(of: &token) { destination -> Bool in
      guard destination.count == auditTokenData.count else { return false }
      auditTokenData.copyBytes(to: destination)
      return true
    }
    guard copied else { return nil }
    let userID = UInt32(audit_token_to_euid(token))
    return userID == 0 ? nil : userID
  }
}
