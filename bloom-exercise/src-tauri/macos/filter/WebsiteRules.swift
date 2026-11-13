import Foundation

/// Domain rules passed to the filter by the containing app's Network Extension configuration.
struct WebsiteRules {
  private let domains: Set<String>
  var isEmpty: Bool { domains.isEmpty }

  init(configuration: [String: Any]?) {
    let values = configuration?["blockedDomains"] as? [String] ?? []
    domains = Set(values.prefix(500).compactMap(Self.host))
  }

  func blocks(_ address: String) -> Bool {
    guard let host = Self.host(address) else { return false }
    return domains.contains { host == $0 || host.hasSuffix("." + $0) }
  }

  func shouldBlockActiveBrowser(host: String?, interactive: Bool, protectionEnabled: Bool,
                                creditAllowed: Bool, usageAllowed: Bool) -> Bool {
    guard interactive, protectionEnabled, !creditAllowed, !usageAllowed, let host else { return false }
    return blocks(host)
  }

  static func host(_ address: String) -> String? {
    let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, value.count <= 2048,
          value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
    let input = value.contains("://") ? value : "https://" + value
    guard let components = URLComponents(string: input),
          let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
          let hostname = components.url?.host?.lowercased() else { return nil }
    let host = hostname.hasSuffix(".") ? String(hostname.dropLast()) : hostname
    let labels = host.split(separator: ".", omittingEmptySubsequences: false)
    guard host.count <= 253, labels.count > 1,
          labels.allSatisfy({ !$0.isEmpty && $0.count <= 63 }) else { return nil }
    return host
  }
}
