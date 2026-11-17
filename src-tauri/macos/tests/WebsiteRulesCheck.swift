import Foundation

@main struct WebsiteRulesCheck {
  static func main() {
    let rules = WebsiteRules(configuration: ["blockedDomains": ["example.com"]])
    precondition(rules.shouldBlockActiveBrowser(host: "example.com", interactive: true,
      protectionEnabled: true, creditAllowed: false, usageAllowed: false))
    precondition(rules.shouldBlockActiveBrowser(host: "www.example.com", interactive: true,
      protectionEnabled: true, creditAllowed: false, usageAllowed: false))
    precondition(!rules.shouldBlockActiveBrowser(host: "example.org", interactive: true,
      protectionEnabled: true, creditAllowed: false, usageAllowed: false))
    precondition(!rules.shouldBlockActiveBrowser(host: "example.com", interactive: true,
      protectionEnabled: true, creditAllowed: true, usageAllowed: false))
    precondition(!rules.shouldBlockActiveBrowser(host: "example.com", interactive: true,
      protectionEnabled: true, creditAllowed: false, usageAllowed: true))
    precondition(!rules.shouldBlockActiveBrowser(host: "example.com", interactive: false,
      protectionEnabled: true, creditAllowed: false, usageAllowed: false))
    precondition(!rules.shouldBlockActiveBrowser(host: "example.com", interactive: true,
      protectionEnabled: false, creditAllowed: false, usageAllowed: false))
    precondition(!rules.shouldBlockActiveBrowser(host: nil, interactive: true,
      protectionEnabled: true, creditAllowed: false, usageAllowed: false))
    precondition(rules.blocks("example.com"))
    precondition(rules.blocks("https://www.EXAMPLE.com/path"))
    precondition(!rules.blocks("notexample.com"))
    precondition(!rules.blocks("example.com.other.test"))
    precondition(rules.blocks("https://user@example.com"))
    precondition(!rules.blocks("not a hostname"))
    let path = ProcessInfo.processInfo.environment["BLOOM_DOMAIN_VECTORS"]!
    let data = try! Data(contentsOf: URL(fileURLWithPath: path))
    let vectors = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
    for vector in vectors {
      let rule = vector["rule"] as! String
      let address = vector["address"] as! String
      let expected = vector["blocked"] as! Bool
      precondition(WebsiteRules(configuration: ["blockedDomains": [rule]]).blocks(address) == expected,
        "Domain policy mismatch: \(rule), \(address)")
    }
    print("macOS website rule checks passed")
  }
}
