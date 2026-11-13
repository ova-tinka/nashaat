enum BloomWebsiteCleanupPolicy {
  static func mayClear(activeProtection: Bool, activeCredit: Bool, openUsage: Bool) -> Bool {
    !activeProtection && !activeCredit && !openUsage
  }

  static func retainedDomains(managedDomains: [String]) -> [String] {
    Array(Set(managedDomains)).sorted()
  }
}
