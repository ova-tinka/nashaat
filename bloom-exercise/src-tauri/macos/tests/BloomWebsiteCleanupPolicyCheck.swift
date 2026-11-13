@main struct BloomWebsiteCleanupPolicyCheck {
  static func main() {
    precondition(BloomWebsiteCleanupPolicy.mayClear(activeProtection: false, activeCredit: false, openUsage: false))
    precondition(!BloomWebsiteCleanupPolicy.mayClear(activeProtection: true, activeCredit: false, openUsage: false))
    precondition(!BloomWebsiteCleanupPolicy.mayClear(activeProtection: false, activeCredit: true, openUsage: false))
    precondition(!BloomWebsiteCleanupPolicy.mayClear(activeProtection: false, activeCredit: false, openUsage: true))
    precondition(BloomWebsiteCleanupPolicy.retainedDomains(managedDomains: ["parent.example", "parent.example"]) == ["parent.example"])
    print("macOS website cleanup policy checks passed")
  }
}
