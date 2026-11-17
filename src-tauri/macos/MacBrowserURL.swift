import Foundation

/// Browser identifiers and static browser scripts; never interpolate a URL or user value into AppleScript.
struct MacBrowserURL {
  private static let browserNames: [String: String] = [
    "com.apple.Safari": "Safari",
    "com.google.Chrome": "Google Chrome",
    "com.google.Chrome.beta": "Google Chrome Beta",
    "com.microsoft.edgemac": "Microsoft Edge",
    "com.brave.Browser": "Brave",
    "company.thebrowser.Browser": "Arc",
    "com.operasoftware.Opera": "Opera",
    "org.mozilla.firefox": "Firefox",
  ]

  private static let automationBrowsers: Set<String> = [
    "com.apple.Safari", "com.google.Chrome", "com.google.Chrome.beta",
    "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser",
    "com.operasoftware.Opera",
  ]

  private static let addressIdentifiers: [String: Set<String>] = [
    "com.apple.Safari": ["AddressAndSearchField", "addressAndSearchField"],
    "com.google.Chrome": ["omnibox"],
    "com.google.Chrome.beta": ["omnibox"],
    "com.microsoft.edgemac": ["omnibox"],
    "com.brave.Browser": ["omnibox"],
    "company.thebrowser.Browser": ["omnibox"],
    "com.operasoftware.Opera": ["addressAndSearchField", "urlbar"],
    "org.mozilla.firefox": ["urlbar-input"],
  ]

  private static let addressLabels: Set<String> = [
    "address bar", "address and search bar", "address and search field",
    "smart search field", "url bar", "omnibox", "search or enter address",
  ]

  static var supportedNames: [String] { browserNames.values.sorted() }

  static func displayName(_ bundleIdentifier: String) -> String? { browserNames[bundleIdentifier] }

  static func isSupported(_ bundleIdentifier: String) -> Bool {
    addressIdentifiers[bundleIdentifier] != nil
  }

  static func isAutomationSupported(_ bundleIdentifier: String) -> Bool {
    automationBrowsers.contains(bundleIdentifier)
  }

  /// Brave profiles can be separate processes while AppleScript addresses the
  /// app by bundle ID. Prefer the frontmost process's address field when AX is
  /// trusted so the monitor evaluates the window that actually owns the flow.
  static func prefersAccessibilityBeforeAutomation(_ bundleIdentifier: String) -> Bool {
    bundleIdentifier == "com.brave.Browser"
  }

  static func isLikelyBrowser(bundleIdentifier: String?, name: String?) -> Bool {
    guard let bundleIdentifier else { return false }
    if browserNames[bundleIdentifier] != nil { return true }
    let identifier = bundleIdentifier.lowercased()
    let display = name?.lowercased() ?? ""
    return identifier.contains("browser") || identifier.contains("vivaldi")
      || identifier.contains("opera") || identifier.contains("firefox")
      || display.contains("browser") || display.contains("chrome") || display.contains("firefox")
      || display.contains("safari") || display.contains("edge") || display.contains("brave")
      || display == "arc" || display.contains("opera") || display.contains("vivaldi")
  }

  static func appleScript(for bundleIdentifier: String) -> String? {
    guard automationBrowsers.contains(bundleIdentifier) else { return nil }
    let tab = bundleIdentifier == "com.apple.Safari" ? "current" : "active"
    return """
    tell application id "\(bundleIdentifier)"
      if (count of windows) is 0 then return ""
      return URL of \(tab) tab of front window
    end tell
    """
  }

  static func host(bundleIdentifier: String?, role: String?, identifier: String?, label: String?, value: String?) -> String? {
    guard let bundleIdentifier, matchesAddressField(bundleIdentifier: bundleIdentifier, role: role, identifier: identifier, label: label),
          let value else { return nil }
    return WebsiteRules.host(value)
  }

  static func matchesAddressField(bundleIdentifier: String?, role: String?, identifier: String?, label: String?) -> Bool {
    guard let bundleIdentifier, let identifiers = addressIdentifiers[bundleIdentifier],
          let role, ["AXTextField", "AXComboBox", "AXSearchField"].contains(role) else { return false }
    let knownIdentifier = identifier.map(identifiers.contains) ?? false
    let normalizedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let knownLabel = normalizedLabel.map(addressLabels.contains) ?? false
    return knownIdentifier || knownLabel
  }
}
