import Foundation

enum MacBrowserPolicyProfile {
  struct TargetBrowser: Equatable {
    let id: String
    let name: String
    let bundleIdentifier: String
  }

  enum ProfileError: LocalizedError {
    case invalidExtensionId

    var errorDescription: String? {
      switch self {
      case .invalidExtensionId:
        return "A valid 32-character Chrome Web Store extension identifier is required."
      }
    }
  }

  static let chromeWebStoreUpdateURL = "https://clients2.google.com/service/update2/crx"

  static let targets: [TargetBrowser] = [
    TargetBrowser(id: "brave", name: "Brave", bundleIdentifier: "com.brave.Browser"),
    TargetBrowser(id: "chrome", name: "Google Chrome", bundleIdentifier: "com.google.Chrome"),
    TargetBrowser(id: "edge", name: "Microsoft Edge", bundleIdentifier: "com.microsoft.edgemac"),
  ]

  static func isValidExtensionId(_ value: String) -> Bool {
    guard value.count == 32 else { return false }
    return value.unicodeScalars.allSatisfy { $0.value >= 97 && $0.value <= 112 } // 'a'...'p'
  }

  static func mobileconfigData(extensionId: String, strict: Bool) throws -> Data {
    guard isValidExtensionId(extensionId) else {
      throw ProfileError.invalidExtensionId
    }

    let forceEntry = "\(extensionId);\(chromeWebStoreUpdateURL)"
    let suffix = strict ? "strict" : "standard"
    let payloadUUID = strict
      ? "C3D7A5E1-7C38-4F6D-9B2A-11E4F9A00202"
      : "B2C694D0-6B27-4E5C-8A19-00D3E89F0101"

    let payloadContent: [[String: Any]] = targets.enumerated().map { index, target in
      var entry: [String: Any] = [
        "PayloadDisplayName": "\(target.name) — Bloom Focus Extension",
        "PayloadIdentifier": "com.focusflow.focusFlowFlutter.browser-policy.\(suffix).\(target.id)",
        "PayloadType": target.bundleIdentifier,
        "PayloadUUID": String(format: "D4E8B6F2-8D49-407E-AC3B-22F50A1B%02d%02d", strict ? 2 : 1, index + 1),
        "PayloadVersion": 1,
        "ExtensionInstallForcelist": [forceEntry],
      ]
      if strict {
        entry["MandatoryExtensionsForIncognitoNavigation"] = [extensionId]
      }
      return entry
    }

    let profile: [String: Any] = [
      "PayloadContent": payloadContent,
      "PayloadDescription": strict
        ? "Installs Bloom Focus across all Brave, Chrome, and Edge profiles and requires it for Private/Incognito navigation."
        : "Installs Bloom Focus across all Brave, Chrome, and Edge profiles on this Mac.",
      "PayloadDisplayName": strict
        ? "Bloom All-Profile Browser Protection (Strict)"
        : "Bloom All-Profile Browser Protection",
      "PayloadIdentifier": "com.focusflow.focusFlowFlutter.browser-policy.\(suffix)",
      "PayloadOrganization": "Bloom",
      "PayloadScope": "System",
      "PayloadType": "Configuration",
      "PayloadUUID": payloadUUID,
      "PayloadVersion": 1,
    ]

    return try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
  }

  static func isManagedPolicyEnforced(bundleIdentifier: String, extensionId: String) -> Bool {
    guard isValidExtensionId(extensionId) else { return false }
    let key = "ExtensionInstallForcelist" as CFString
    let appId = bundleIdentifier as CFString
    guard CFPreferencesAppValueIsForced(key, appId),
          let value = CFPreferencesCopyAppValue(key, appId) as? [String] else {
      return false
    }
    return value.contains { entry in
      entry == extensionId || entry.hasPrefix("\(extensionId);")
    }
  }

  static func managedPolicySummary(extensionId: String?) -> [String: Bool] {
    var result: [String: Bool] = [:]
    for target in targets {
      if let extensionId {
        result[target.id] = isManagedPolicyEnforced(bundleIdentifier: target.bundleIdentifier, extensionId: extensionId)
      } else {
        result[target.id] = false
      }
    }
    return result
  }
}
