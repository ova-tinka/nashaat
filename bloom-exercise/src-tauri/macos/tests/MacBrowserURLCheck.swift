import Foundation

@main struct MacBrowserURLCheck {
  static func main() {
    precondition(MacBrowserURL.isSupported("com.apple.Safari"))
    precondition(MacBrowserURL.isAutomationSupported("com.apple.Safari"))
    precondition(MacBrowserURL.isAutomationSupported("company.thebrowser.Browser"))
    precondition(MacBrowserURL.isAutomationSupported("com.operasoftware.Opera"))
    precondition(!MacBrowserURL.isAutomationSupported("org.mozilla.firefox"))
    precondition(MacBrowserURL.prefersAccessibilityBeforeAutomation("com.brave.Browser"))
    precondition(!MacBrowserURL.prefersAccessibilityBeforeAutomation("com.apple.Safari"))
    precondition(MacBrowserURL.isLikelyBrowser(bundleIdentifier: "com.example.unknown", name: "Unknown Browser"))
    precondition(!MacBrowserURL.isSupported("com.example.browser"))
    precondition(MacBrowserURL.appleScript(for: "com.apple.Safari")?.contains("current tab") == true)
    precondition(MacBrowserURL.appleScript(for: "com.google.Chrome")?.contains("active tab") == true)
    precondition(MacBrowserURL.appleScript(for: "com.example.browser") == nil)
    precondition(MacBrowserURL.host(bundleIdentifier: "com.apple.Safari", role: "AXComboBox",
      identifier: "AddressAndSearchField", label: nil, value: "https://example.com/path") == "example.com")
    precondition(MacBrowserURL.host(bundleIdentifier: "com.google.Chrome", role: "AXTextField",
      identifier: nil, label: "Address and search bar", value: "https://sub.example.com") == "sub.example.com")
    precondition(MacBrowserURL.host(bundleIdentifier: "com.apple.Safari", role: "AXTextField",
      identifier: nil, label: "Page title", value: "https://example.com") == nil)
    precondition(MacBrowserURL.host(bundleIdentifier: "com.example.browser", role: "AXTextField",
      identifier: "omnibox", label: "Address bar", value: "https://example.com") == nil)
    precondition(MacBrowserURL.host(bundleIdentifier: "org.mozilla.firefox", role: "AXTextField",
      identifier: "urlbar-input", label: nil, value: "Search phrase") == nil)
    print("macOS browser URL checks passed")
  }
}
