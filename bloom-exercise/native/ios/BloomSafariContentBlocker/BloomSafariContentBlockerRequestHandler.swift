import Foundation
import UniformTypeIdentifiers

final class BloomSafariContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
  private let alwaysRulesKey = "bloom_safari_always_domains"
  private let focusRulesKey = "bloom_safari_focus_domains"
  private let focusActiveKey = "bloom_safari_focus_active"
  private let focusSuspendedKey = "bloom_safari_focus_suspended"

  func beginRequest(with context: NSExtensionContext) {
    let domains = activeDomains()
    let rules: [[String: Any]] = domains.map { domain in
      [
        "trigger": [
          "url-filter": Self.urlFilter(for: domain),
          "url-filter-is-case-sensitive": false,
        ],
        "action": ["type": "block"],
      ]
    }
    guard let data = try? JSONSerialization.data(withJSONObject: rules, options: []) else {
      context.cancelRequest(withError: NSError(domain: "BloomSafariContentBlocker", code: 1))
      return
    }

    let item = NSExtensionItem()
    item.attachments = [NSItemProvider(item: data as NSData, typeIdentifier: UTType.json.identifier)]
    context.completeRequest(returningItems: [item])
  }

  private func activeDomains() -> [String] {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "BloomAppGroup") as? String,
          let defaults = UserDefaults(suiteName: group) else { return [] }

    var domains = Set(defaults.stringArray(forKey: alwaysRulesKey) ?? [])
    if defaults.bool(forKey: focusActiveKey) && !defaults.bool(forKey: focusSuspendedKey) {
      domains.formUnion(defaults.stringArray(forKey: focusRulesKey) ?? [])
    }
    return domains.filter(Self.isValidDomain).sorted().map { $0 }
  }

  private static func isValidDomain(_ domain: String) -> Bool {
    guard domain.count <= 253, domain == domain.lowercased() else { return false }
    let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
    guard labels.count >= 2 else { return false }
    return labels.allSatisfy { label in
      label.count <= 63 && label.range(of: #"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$"#, options: .regularExpression) != nil
    }
  }

  private static func urlFilter(for domain: String) -> String {
    let escaped = domain.replacingOccurrences(of: ".", with: #"\."#)
    return #"^https?://+([^:/]+\.)?"# + escaped + #"[:/]"#
  }
}
