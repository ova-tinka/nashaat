import AppKit
import ApplicationServices
import Foundation

struct MacBrowserAddressResult {
  let bundleIdentifier: String
  let browserName: String
  let host: String?
  let readable: Bool
  let source: String
  let automationStatus: String
}

/// Reads only the active tab URL, using browser automation first and the browser's
/// accessibility address field as a fallback. It never reads page content.
enum MacBrowserAddress {
  static func current(for app: NSRunningApplication, accessibilityAllowed: Bool) -> MacBrowserAddressResult? {
    guard let bundleIdentifier = app.bundleIdentifier,
          MacBrowserURL.isLikelyBrowser(bundleIdentifier: bundleIdentifier, name: app.localizedName) else { return nil }
    let name = MacBrowserURL.displayName(bundleIdentifier) ?? app.localizedName ?? "Unsupported browser"
    var automationStatus = "notSupported"
    let accessibilityFirst = accessibilityAllowed
      && MacBrowserURL.prefersAccessibilityBeforeAutomation(bundleIdentifier)
    if accessibilityFirst,
       let host = accessibilityHost(for: app, bundleIdentifier: bundleIdentifier) {
      return MacBrowserAddressResult(bundleIdentifier: bundleIdentifier, browserName: name,
        host: host, readable: true, source: "accessibility", automationStatus: "notRequested")
    }

    if let source = MacBrowserURL.appleScript(for: bundleIdentifier) {
      var error: NSDictionary?
      if let descriptor = NSAppleScript(source: source)?.executeAndReturnError(&error) {
        automationStatus = "available"
        let value = descriptor.stringValue ?? ""
        if let host = WebsiteRules.host(value) {
          return MacBrowserAddressResult(bundleIdentifier: bundleIdentifier, browserName: name,
            host: host, readable: true, source: "automation", automationStatus: automationStatus)
        }
      } else {
        let errorNumber = (error?[NSAppleScript.errorNumber] as? NSNumber)?.intValue
        automationStatus = errorNumber == -1743 ? "permissionRequired" : "unavailable"
      }
    }

    if accessibilityAllowed, !accessibilityFirst,
       let host = accessibilityHost(for: app, bundleIdentifier: bundleIdentifier) {
      return MacBrowserAddressResult(bundleIdentifier: bundleIdentifier, browserName: name,
        host: host, readable: true, source: "accessibility", automationStatus: automationStatus)
    }
    return MacBrowserAddressResult(bundleIdentifier: bundleIdentifier, browserName: name,
      host: nil, readable: false, source: MacBrowserURL.isSupported(bundleIdentifier) ? "unreadable" : "unsupported",
      automationStatus: automationStatus)
  }

  private static func accessibilityHost(for app: NSRunningApplication, bundleIdentifier: String) -> String? {
    guard app.processIdentifier > 0 else { return nil }
    let application = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(application, 0.08)
    var focusedWindow: CFTypeRef?
    guard AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
          let focusedWindow, CFGetTypeID(focusedWindow) == AXUIElementGetTypeID() else { return nil }
    let window = unsafeBitCast(focusedWindow, to: AXUIElement.self)
    return findAddress(in: window, bundleIdentifier: bundleIdentifier, depth: 0, remaining: 300)
  }

  private static func findAddress(in element: AXUIElement, bundleIdentifier: String, depth: Int, remaining: Int) -> String? {
    guard depth <= 12, remaining > 0 else { return nil }
    AXUIElementSetMessagingTimeout(element, 0.08)
    let role = stringAttribute(element, kAXRoleAttribute as CFString)
    let identifier = stringAttribute(element, "AXIdentifier" as CFString)
    let label = stringAttribute(element, kAXDescriptionAttribute as CFString)
      ?? stringAttribute(element, kAXTitleAttribute as CFString)
    if MacBrowserURL.matchesAddressField(bundleIdentifier: bundleIdentifier, role: role,
         identifier: identifier, label: label),
       let value = attribute(element, kAXValueAttribute as CFString) as? String,
       let host = WebsiteRules.host(value) { return host }

    guard let children = attribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] else { return nil }
    var budget = remaining - 1
    for child in children.prefix(budget) {
      if let host = findAddress(in: child, bundleIdentifier: bundleIdentifier, depth: depth + 1, remaining: budget) { return host }
      budget -= 1
      if budget <= 0 { break }
    }
    return nil
  }

  private static func stringAttribute(_ element: AXUIElement, _ key: CFString) -> String? {
    attribute(element, key) as? String
  }

  private static func attribute(_ element: AXUIElement, _ key: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key, &value) == .success else { return nil }
    return value
  }
}
